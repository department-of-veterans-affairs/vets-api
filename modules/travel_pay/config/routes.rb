# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  get '/pings/ping', to: 'pings#ping'
  get '/pings/authorized_ping', to: 'pings#authorized_ping'
  resources :claims
end
