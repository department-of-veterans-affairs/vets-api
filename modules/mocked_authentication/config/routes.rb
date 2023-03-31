# frozen_string_literal: true

MockedAuthentication::Engine.routes.draw do
  get '/authorize', to: 'credential#authorize'
  get '/credential_list', to: 'credential#credential_list'
end
