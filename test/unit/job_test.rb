# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Job do
  let(:job_class) do
    Class.new(ApplicationJob) do
      attr :recorded_perform_now_tenant

      def perform
        @recorded_perform_now_tenant = TenantedApplicationRecord.current_tenant
      end
    end
  end

  with_scenario(:primary_db, :primary_record) do
    describe "#tenant" do
      describe "integration enabled" do
        test "in untenanted context" do
          ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
            TenantedApplicationRecord.while_untenanted do
              assert_nil(job_class.new.tenant)
            end
          end
        end

        test "in tenanted context" do
          ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
            TenantedApplicationRecord.while_tenanted("foo") do
              assert_equal("foo", job_class.new.tenant)
            end
          end
        end
      end

      describe "integration disabled" do
        test "in untenanted context" do
          assert_nil(ActiveRecord::Tenanted.connection_class)

          TenantedApplicationRecord.while_untenanted do
            assert_nil(job_class.new.tenant)
          end
        end

        test "in tenanted context" do
          assert_nil(ActiveRecord::Tenanted.connection_class)

          TenantedApplicationRecord.while_tenanted("foo") do
            assert_nil(job_class.new.tenant)
          end
        end
      end
    end

    describe "serialize/deserialize" do
      describe "integration enabled" do
        test "in untenanted context" do
          ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
            job_data = TenantedApplicationRecord.while_untenanted do
              job_class.new.serialize
            end
            job_later = job_class.new.tap { |j| j.deserialize(job_data) }

            assert_nil(job_later.tenant)
          end
        end

        test "in tenanted context" do
          ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
            job_data = TenantedApplicationRecord.while_tenanted("foo") do
              job_class.new.serialize
            end
            job_later = job_class.new.tap { |j| j.deserialize(job_data) }

            assert_equal("foo", job_later.tenant)
          end
        end
      end

      describe "integration disabled" do
        test "in untenanted context" do
          assert_nil(ActiveRecord::Tenanted.connection_class)

          job_data = TenantedApplicationRecord.while_untenanted do
            job_class.new.serialize
          end
          job_later = job_class.new.tap { |j| j.deserialize(job_data) }

          assert_nil(job_later.tenant)
        end

        test "in tenanted context" do
          assert_nil(ActiveRecord::Tenanted.connection_class)

          job_data = TenantedApplicationRecord.while_tenanted("foo") do
            job_class.new.serialize
          end
          job_later = job_class.new.tap { |j| j.deserialize(job_data) }

          assert_nil(job_later.tenant)
        end
      end
    end

    describe "perform_now" do
      describe "integration enabled" do
        test "in untenanted context" do
          ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
            job = TenantedApplicationRecord.while_untenanted do
              job_class.new
            end

            job.perform_now

            assert_nil(job.recorded_perform_now_tenant)
          end
        end

        test "in tenanted context" do
          ActiveRecord::Tenanted.stub(:connection_class, TenantedApplicationRecord) do
            job = TenantedApplicationRecord.while_tenanted("foo") do
              job_class.new
            end

            job.perform_now

            assert_equal("foo", job.recorded_perform_now_tenant)
          end
        end
      end

      describe "integration disabled" do
        test "in untenanted context" do
          assert_nil(ActiveRecord::Tenanted.connection_class)

          job = TenantedApplicationRecord.while_untenanted do
            job_class.new
          end

          job.perform_now

          assert_nil(job.recorded_perform_now_tenant)
        end

        test "in tenanted context" do
          assert_nil(ActiveRecord::Tenanted.connection_class)

          job = TenantedApplicationRecord.while_tenanted("foo") do
            job_class.new
          end

          job.perform_now

          assert_nil(job.recorded_perform_now_tenant)
        end
      end
    end
  end
end
