# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# Bootsnap is used to speed up application load time. Enabled for development/test
# environments. Can be disabled with DISABLE_BOOTSNAP environment variable
should_setup_bootsnap = %w[development test].include?(ENV['RAILS_ENV']) && !ENV['DISABLE_BOOTSNAP']
require 'bootsnap/setup' if should_setup_bootsnap
