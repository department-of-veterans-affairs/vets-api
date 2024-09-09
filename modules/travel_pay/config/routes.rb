# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  # TODO: remove this mapping once vets-website
  # is pointing to the /v0/claims routes
  resources :claims, controller: '/travel_pay/v0/claims'

  namespace :v0 do
    resources :claims
  end
end
