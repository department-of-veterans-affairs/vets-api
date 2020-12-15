# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get '/claims-and-appeals-overview', to: 'claims_and_appeals#index'
    get '/letters', to: 'letters#index'
    get '/letters/beneficiary', to: 'letters#beneficiary'
    post '/letters/:type/download', to: 'letters#download'
    get '/military-service-history', to: 'military_information#get_service_history'
    get '/payment-information/benefits', to: 'payment_information#index'
    put '/payment-information/benefits', to: 'payment_information#update'
    get '/user', to: 'users#show'
    get '/user/logout', to: 'users#logout'
    post '/user/addresses/validate', to: 'addresses#validate'
    post '/user/addresses', to: 'addresses#create'
    post '/user/addresses/validate', to: 'addresses#validate'
    put '/user/addresses', to: 'addresses#update'
    post '/user/emails', to: 'emails#create'
    put '/user/emails', to: 'emails#update'
    post '/user/phones', to: 'phones#create'
    put '/user/phones', to: 'phones#update'
  end
end
