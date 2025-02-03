# frozen_string_literal: true

require "active_record"

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem_extension(ActiveRecord)
loader.setup

module ActiveRecord
  module Tenanted
  end
end

loader.eager_load
