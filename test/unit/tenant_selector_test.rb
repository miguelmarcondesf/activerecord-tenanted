# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::TenantSelector do
  let(:fake_env) { Rack::Request.new({}) }

  let(:fake_app) do
    Class.new do
      attr_reader :env, :tenant

      def call(env)
        @env = env
        @tenant = TenantedApplicationRecord.current_tenant

        [ 200, {}, [ "OK" ] ]
      end
    end.new
  end

  setup do
    Rails.application.config.active_record_tenanted.connection_class = "TenantedApplicationRecord"
    Rails.application.config.active_record_tenanted.tenant_resolver = resolver
  end

  with_scenario(:primary_db, :primary_record) do
    describe "when no tenant is resolved" do
      let(:resolver) { ->(request) { nil } }

      test "execute as untenanted" do
        selector = ActiveRecord::Tenanted::TenantSelector.new(fake_app)

        response = selector.call(fake_env)

        assert_equal(200, response.first)
        assert_equal(fake_env, fake_app.env)
        assert_nil(fake_app.tenant)
      end
    end

    describe "when nonexistent tenant is resolved" do
      let(:resolver) { ->(request) { "does-not-exist" } }

      test "returns 404" do
        selector = ActiveRecord::Tenanted::TenantSelector.new(fake_app)

        response = selector.call(fake_env)

        assert_nil(fake_app.env, "Rack app should not have been invoked")
        assert_equal(404, response.first)
      end
    end

    describe "when an existing tenant is resolved" do
      let(:resolver) { ->(request) { "foo" } }

      setup { TenantedApplicationRecord.create_tenant("foo") }

      test "execute while tenanted" do
        selector = ActiveRecord::Tenanted::TenantSelector.new(fake_app)

        response = selector.call(fake_env)

        assert_equal(200, response.first)
        assert_equal(fake_env, fake_app.env)
        assert_equal("foo", fake_app.tenant)
      end

      test "disallow tenant swapping" do
        fake_app = Class.new do
          def call(env)
            TenantedApplicationRecord.with_tenant("bar") { }
          end
        end.new

        selector = ActiveRecord::Tenanted::TenantSelector.new(fake_app)

        # an odd exception to raise here IMHO, but that's the current behavior of Rails
        assert_raises(ArgumentError) do
          selector.call(fake_env)
        end
      end
    end
  end
end
