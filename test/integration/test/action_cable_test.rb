require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "default host and tenant" do
    connect

    assert_equal("#{ApplicationRecord.current_tenant}.example.com", connection.request.host)
    assert_equal(ApplicationRecord.current_tenant, connection.current_tenant)
  end

  test "with_tenant host and tenant" do
    ApplicationRecord.with_tenant("action-cable-test-case-host") do
      assert_reject_connection { connect }
    end

    ApplicationRecord.create_tenant("action-cable-test-case-host") do
      connect
    end

    assert_equal("action-cable-test-case-host.example.com", connection.request.host)
    assert_equal("action-cable-test-case-host", connection.current_tenant)
  end

  test "without_tenant is an error" do
    assert_reject_connection do
      ApplicationRecord.without_tenant { connect }
    end
  end

  test "overridden host and tenant" do
    tenant = ApplicationRecord.current_tenant
    ApplicationRecord.without_tenant do
      connect env: { "HTTP_HOST" => "#{tenant}.example.com" }
    end

    assert_equal("#{tenant}.example.com", connection.request.host)
    assert_equal(tenant, connection.current_tenant)
  end

  test "overridden host and tenant and tenant resolver" do
    domain = "action-cable-test-case-host"
    tenant = "asdf" + domain
    ApplicationRecord.create_tenant(tenant)

    @old_tenant_resolver = Rails.application.config.active_record_tenanted.tenant_resolver
    Rails.application.config.active_record_tenanted.tenant_resolver = ->(request) { "asdf" + request.subdomain }

    ApplicationRecord.without_tenant do
      connect env: { "HTTP_HOST" => "#{domain}.example.com" }
    end

    assert_equal("#{domain}.example.com", connection.request.host)
    assert_equal(tenant, connection.current_tenant)
  ensure
    Rails.application.config.active_record_tenanted.tenant_resolver = @old_tenant_resolver
  end

  test "untenanted request" do
    @old_tenant_resolver = Rails.application.config.active_record_tenanted.tenant_resolver
    Rails.application.config.active_record_tenanted.tenant_resolver = ->(request) { nil }

    ApplicationRecord.without_tenant do
      connect
    end

    assert_nil(connection.current_tenant)
  ensure
    Rails.application.config.active_record_tenanted.tenant_resolver = @old_tenant_resolver
  end
end
