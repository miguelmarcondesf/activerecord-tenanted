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
end
