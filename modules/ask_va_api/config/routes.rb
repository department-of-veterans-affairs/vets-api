# frozen_string_literal: true

AskVAApi::Engine.routes.draw do
  namespace :v0 do
    resources :static_data, only: %i[index]
    resources :static_data_auth, only: %i[index]
    get '/inquiries', to: 'inquiries#index'
    get '/inquiries/:inquiry_number', to: 'inquiries#show'
    get '/categories', to: 'static_data#categories'
  end
end
