require "test_helper"

class ApplicationCable::ConnectionTest < ActionCable::Connection::TestCase
  test "default host and tenant" do
    connect

    assert_equal("#{ApplicationRecord.current_tenant}.example.com", connection.request.host)
    assert_equal(ApplicationRecord.current_tenant, connection.current_tenant)
  end

  test "while_tenanted host and tenant" do
    ApplicationRecord.while_tenanted("action-cable-test-case-host") do
      assert_reject_connection { connect }

      Note.first # create the tenant

      connect
    end

    assert_equal("action-cable-test-case-host.example.com", connection.request.host)
    assert_equal("action-cable-test-case-host", connection.current_tenant)
  end

  test "while_untenanted is an error" do
    assert_reject_connection do
      ApplicationRecord.while_untenanted { connect }
    end
  end

  test "overridden host and tenant" do
    tenant = ApplicationRecord.current_tenant
    ApplicationRecord.while_untenanted do
      connect env: { "HTTP_HOST" => "#{tenant}.example.com" }
    end

    assert_equal("#{tenant}.example.com", connection.request.host)
    assert_equal(tenant, connection.current_tenant)
  end
end
