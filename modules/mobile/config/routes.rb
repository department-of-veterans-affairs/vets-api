# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get '/user', to: 'users#show'
    get '/letters', to: 'letters#letters'
    get '/letters/beneficiary', to: 'letters#beneficiary'
    put '/user/addresses', to: 'addresses#update'
    put '/user/emails', to: 'emails#update'
    post '/letters/:id', to: 'letters#download'
  end
end
