# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  get '/pings/ping', to: 'pings#ping'
  get '/pings/authorized_ping', to: 'pings#authorized_ping'

  # TODO: remove this mapping once vets-website
  # is pointing to the /v0/claims routes
  resources :claims, controller: '/travel_pay/v0/claims'

  namespace :v0 do
    resources :claims
  end
end
