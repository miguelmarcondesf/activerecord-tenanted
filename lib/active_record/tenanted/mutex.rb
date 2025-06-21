# frozen_string_literal: true

module ActiveRecord
  module Tenanted
    module Mutex
      #
      #  This flock-based mutex is intended to hold a lock while the tenant database is in the
      #  process of being created and migrated (i.e., "made ready").
      #
      #  The creation-and-migration time span is generally very short, and only happens once at the
      #  beginning of the database file's existence. We can take advantage of these characteristics
      #  to make sure the readiness check is cheap for the majority of the database's life.
      #
      #  1. The lock file is created and an advisory lock is acquired before the database file is
      #     created.
      #  2. Once the database migration has been completed and the database is ready, the lock is
      #     released and the file is removed.
      #
      #  If the lock file exists, then a relatively expensive shared lock must be acquired to ensure
      #  the database is ready to use. However, if the lock file does not exist (the majority of the
      #  database's life!) then the readiness check is a cheap check for existing on the database
      #  file.
      #
      class Ready
        class << self
          def lock(database_path)
            path = lock_file_path(database_path)
            FileUtils.mkdir_p(File.dirname(path))

            # mode "w" to create the file if it does not exist.
            File.open(path, "w") do |f|
              f.flock(File::LOCK_EX) # blocking!
              yield
            ensure
              File.unlink(path)
            end
          end

          def locked?(database_path)
            path = lock_file_path(database_path)

            if File.exist?(path)
              result = nil
              begin
                # mode "r" to avoid creating the file if it does not exist.
                File.open(path, "r") do |f|
                  result = f.flock(File::LOCK_SH | File::LOCK_NB)
                end
                result != 0
              rescue Errno::ENOENT
                # the file was deleted between the existence check and the open
                false
              end
            else
              false
            end
          end

          def lock_file_path(database_path)
            database_path.to_s + ".ready_lock"
          end
        end
      end
    end
  end
end
