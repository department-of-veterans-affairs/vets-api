# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get '/user', to: 'users#show'
    get '/military-service-history', to: 'military_information#get_service_history'
    get '/payment_information', to: 'payment_information#index'
    put '/user/addresses', to: 'addresses#update'
    put '/user/emails', to: 'emails#update'
    put '/user/phones', to: 'phones#update'
    put '/payment_information', to: 'payment_information#update'
  end
end
