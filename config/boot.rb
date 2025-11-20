# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.
require 'bootsnap/setup' # Speed up boot time by caching expensive operations.

# Add lib to load path for mail compatibility patch
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__)) unless $LOAD_PATH.include?(File.expand_path('../lib', __dir__))
