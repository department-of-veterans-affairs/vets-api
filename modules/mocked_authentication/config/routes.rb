# frozen_string_literal: true

MockedAuthentication::Engine.routes.draw do
  get '/authorize', to: 'mock_credential#authorize'
end
