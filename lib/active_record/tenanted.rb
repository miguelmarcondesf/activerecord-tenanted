# frozen_string_literal: true

require "active_record"

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem_extension(ActiveRecord)
loader.setup

module ActiveRecord
  module Tenanted
    class Error < StandardError; end
  end
end

loader.eager_load
