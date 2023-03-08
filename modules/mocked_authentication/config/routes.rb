# frozen_string_literal: true

MockedAuthentication::Engine.routes.draw do
  get '/authorize', to: 'credential_providers#authorize'
end
