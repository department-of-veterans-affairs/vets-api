# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  resources :claims
  get '/pings/ping', to: 'pings#ping'
end
