# frozen_string_literal: true

require "test_helper"

describe ActiveRecord::Tenanted::Mutex::Ready do
  let(:db_path) { File.join(Dir.mktmpdir, "test.db") }

  def assert_locked(db_path, message)
    assert ActiveRecord::Tenanted::Mutex::Ready.locked?(db_path), message
  end

  def assert_not_locked(db_path, message)
    assert_not ActiveRecord::Tenanted::Mutex::Ready.locked?(db_path), message
  end

  describe ".locked?" do
    test "returns false if lock file does not exist" do
      assert_not_locked(db_path, "Lock should not be acquired when lock file does not exist")
    end

    test "returns true if lock file exists and is locked" do
      ActiveRecord::Tenanted::Mutex::Ready.lock(db_path) do
        assert_locked db_path, "Lock should be acquired when lock file exists"
      end

      assert_not_locked(db_path, "Lock should be released after the block is executed")
    end

    test "returns false if lock file exists but is not locked" do
      lock_file_path = ActiveRecord::Tenanted::Mutex::Ready.lock_file_path(db_path)

      # create a fake lock file
      File.open(lock_file_path, "w+") do |f|
        assert_not_locked(db_path, "Lock should not be acquired when lock file exists but is not locked")
      end
    end
  end

  describe ".lock" do
    test "block is yielded" do
      called = false

      ActiveRecord::Tenanted::Mutex::Ready.lock(db_path) { called = true }

      assert called, "Block was not called"
    end

    test "lock file is removed after the lock is released" do
      lock_file_path = ActiveRecord::Tenanted::Mutex::Ready.lock_file_path(db_path)

      ActiveRecord::Tenanted::Mutex::Ready.lock(db_path) do
        assert File.exist?(lock_file_path), "Lock file should exist while the block is executing"
      end

      assert_not File.exist?(lock_file_path), "Lock file should be removed after the block is executed"
    end

    test "lock is acquired" do
      assert_not_locked(db_path, "Lock should not be acquired before the block")

      ActiveRecord::Tenanted::Mutex::Ready.lock(db_path) do
        assert_locked(db_path, "Lock should be acquired during the block")
      end

      assert_not_locked(db_path, "Lock should not be acquired after the block")
    end

    test "lock is released if an exception is raised" do
      lock_file_path = ActiveRecord::Tenanted::Mutex::Ready.lock_file_path(db_path)

      assert_not_locked(db_path, "Lock should not be acquired before the block")

      assert_raises do
        ActiveRecord::Tenanted::Mutex::Ready.lock(db_path) do
          assert_locked(db_path, "Lock should be acquired during the block")
          raise "Test exception"
        end
      end

      assert_not_locked(db_path, "Lock should be released after an exception is raised")
      assert_not File.exist?(lock_file_path), "Lock file should be removed after an exception is raised"
    end

    test "directory is created if necessary" do
      dir = Dir.mktmpdir
      subdir = File.join(dir, "subdir")
      db_path = File.join(subdir, "test.db")

      assert_not(File.exist?(subdir))

      ActiveRecord::Tenanted::Mutex::Ready.lock(db_path) { }

      assert(File.exist?(subdir))
    end
  end
end
