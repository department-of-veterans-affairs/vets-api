# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get   '/letters', to: 'letters#index'
    get   '/letters/beneficiary', to: 'letters#beneficiary'
    post  '/letters/:type/download', to: 'letters#download'
    get   '/military-service-history', to: 'military_information#get_service_history'
    get   '/payment-information/benefits', to: 'payment_information#index'
    put   '/payment-information/benefits', to: 'payment_information#update'
    get   '/user', to: 'users#show'
    put   '/user/addresses', to: 'addresses#update'
    put   '/user/emails', to: 'emails#update'
    get   '/user/logout', to: 'users#logout'
    put   '/user/phones', to: 'phones#update'
    get   '/user/transactions/:transaction_id', to: 'transactions#show'
  end
end
