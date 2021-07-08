# frozen_string_literal: true

# Be sure to restart your server when you modify this file.
require 'sidekiq/web'

Rails.application.config.session_store :cookie_store, key: '_vets_api_session'

Sidekiq::Web.set :sessions, false
