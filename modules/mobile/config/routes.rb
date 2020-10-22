# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get '/user', to: 'users#show'
    get '/user/logout', to: 'users#logout'
    get '/letters', to: 'letters#index'
    get '/letters/beneficiary', to: 'letters#beneficiary'
    get '/military-service-history', to: 'military_information#get_service_history'
    put '/user/addresses', to: 'addresses#update'
    put '/user/emails', to: 'emails#update'
    put '/user/phones', to: 'phones#update'
    post '/letters/:type/download', to: 'letters#download'
  end
end
