# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  resources :claims
  resources :pings
end
