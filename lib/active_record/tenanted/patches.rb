# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Patches
      # TODO: I think this is needed because there was no followup to rails/rails#46270.
      # See rails/rails@901828f2 from that PR for background.
      module DatabaseTasks
        private def with_temporary_pool(db_config, clobber: false)
          original_db_config = begin
            migration_class.connection_db_config
          rescue ActiveRecord::ConnectionNotDefined
            nil
          end

          begin
            pool = migration_class.connection_handler.establish_connection(db_config, clobber: clobber)

            yield pool
          ensure
            migration_class.connection_handler.establish_connection(original_db_config, clobber: clobber) if original_db_config
          end
        end
      end
    end
  end
end
