# frozen_string_literal: true

require 'sidekiq/web'
require 'sidekiq-scheduler/web'
require 'sidekiq/pro/web' if Gem.loaded_specs.key?('sidekiq-pro')
require 'sidekiq-ent/web' if Gem.loaded_specs.key?('sidekiq-ent')
require 'sidekiq/web/authorization'

Sidekiq::Web.set :session_secret, Rails.application.secret_key_base

Sidekiq::Web.authorize do |env, method, path|
  Sidekiq::Web::Authorization.request_authorized?(env, method, path)
end
