# frozen_string_literal: true

Preneeds::Engine.routes.draw do
  namespace :v0 do
    post '/address_validation', to: 'address_validation#create'
  end
end
