# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  namespace :v0 do
    resources :claims
  end
end
