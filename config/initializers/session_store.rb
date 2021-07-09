# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :active_record_store, key: '_vets_api_session', expire_after: 1.month
Rails.application.config.middleware.use Rails.application.config.session_store, Rails.application.config.session_options
