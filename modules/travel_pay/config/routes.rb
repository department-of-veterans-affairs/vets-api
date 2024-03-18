# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  get '/pings/ping', to: 'pings#ping'
end
