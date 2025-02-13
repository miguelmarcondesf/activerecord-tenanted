# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::UntenantedConnectionPool do
  let(:config) { Object.new }
  let(:subject) { ActiveRecord::Tenanted::UntenantedConnectionPool.new(config) }

  [ :lease_connection,
    :checkout,
    :with_connection,
    :new_connection
  ].each do |method|
    test "#{method} raises NoTenantError" do
      assert_raises(ActiveRecord::Tenanted::NoTenantError) do
        subject.send(method)
      end
    end
  end
end
