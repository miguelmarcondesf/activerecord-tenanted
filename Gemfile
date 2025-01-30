# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in active_record-tenanted.gemspec.
gemspec

# Your gem is dependent on a prerelease version of Rails. Once you can lock this
# dependency down to a specific version, move it to your gemspec.
gem "rails", github: "rails/rails", branch: "8-0-stable"

gem "puma"

gem "sqlite3"

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"

group :rubocop do
  gem "standard", "1.44.0", require: false
  gem "rubocop-minitest", "0.36.0", require: false
  gem "rubocop-packaging", "0.5.2", require: false
  gem "rubocop-rails", "2.29.1", require: false
  gem "rubocop-rake", "0.6.0", require: false
end
