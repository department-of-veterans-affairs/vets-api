# frozen_string_literal: true

TravelPay::Engine.routes.draw do
  namespace :v0 do
    resources :claims

    scope '/claims/:claim_id' do
      resources :documents, only: %i[index show]
    end
  end
end
