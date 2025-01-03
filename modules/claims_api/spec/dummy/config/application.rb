require_relative 'boot'
require 'rails/all'

Bundler.require(*Rails.groups)
require 'claims_api'

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
  end
end