# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Bootsnap is used to speed up application load time. Enabled for development/test
# environments.
require 'bootsnap/setup' if %w[development test].include?(ENV['RAILS_ENV'])
