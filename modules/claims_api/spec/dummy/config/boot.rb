# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

clients_path = File.expand_path('../../../app/clients', __dir__)
$LOAD_PATH.unshift(clients_path) unless $LOAD_PATH.include?(clients_path)