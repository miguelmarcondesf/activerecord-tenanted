# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::StorageService do
  describe "DiskService" do
    with_scenario(:primary_db, :primary_record) do
      setup do
        User.has_one_attached :image
      end

      describe "initialize" do
        test "is not tenanted by default" do
          assert_not_predicate(ActiveStorage::Service::DiskService.new(root: "/path/to/storage"), :tenanted?)
        end

        test "can be tenanted in the configuration" do
          assert_predicate(ActiveStorage::Service::DiskService.new(root: "/path/to/storage", tenanted: true), :tenanted?)
        end

        test "can be explicitly untenanted in the configuration" do
          assert_not_predicate(ActiveStorage::Service::DiskService.new(root: "/path/to/storage", tenanted: false), :tenanted?)
        end
      end

      describe ".root" do
        describe "configured as untenanted" do
          test "returns the root path" do
            service = ActiveStorage::Service::DiskService.new(root: "/path/to/storage")
            assert_equal("/path/to/storage", service.root)
          end
        end

        describe "configured as tenanted" do
          let(:service) do
            ActiveStorage::Service::DiskService.new(root: "/path/to/%{tenant}/storage", tenanted: true)
          end

          test "raises exception if connection class is not configured" do
            assert_raises(ActiveRecord::Tenanted::TenantConfigurationError) do
              service.root
            end
          end

          test "raises exception while untenanted" do
            ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
              assert_raises(ActiveRecord::Tenanted::NoTenantError) do
                service.root
              end
            end
          end

          test "returns current tenant while tenanted" do
            ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
              TenantedApplicationRecord.while_tenanted("foo") do
                assert_equal("/path/to/foo/storage", service.root)
              end
            end
          end
        end
      end
    end
  end
end
