# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get '/user', to: 'users#show'
    put '/user/addresses', to: 'addresses#update'
    put '/user/emails', to: 'emails#update'
  end
end
