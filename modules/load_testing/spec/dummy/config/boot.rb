ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../Gemfile', __dir__)
ENV['RAILS_ENV'] = 'test'
ENV['SKIP_MAIN_APP'] = 'true'

require 'bundler/setup'
$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__) 