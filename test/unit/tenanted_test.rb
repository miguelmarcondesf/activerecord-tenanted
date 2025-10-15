# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted do
  with_scenario(:primary_db, :primary_record) do
    test ".connection_class" do
      Rails.application.config.active_record_tenanted.connection_class = "TenantedApplicationRecord"
      assert_equal TenantedApplicationRecord, ActiveRecord::Tenanted.connection_class

      Rails.application.config.active_record_tenanted.connection_class = nil
      assert_nil ActiveRecord::Tenanted.connection_class
    end
  end
end
