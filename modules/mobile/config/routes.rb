# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#index'

  namespace :v0 do
    get '/user', to: 'users#show'
  end

  namespace :v0 do
    get '/military-service-history', to: 'military_information#get_service_history'
  end
end
