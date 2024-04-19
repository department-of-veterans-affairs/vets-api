# frozen_string_literal: true

AskVAApi::Engine.routes.draw do
  namespace :v0 do
    resources :static_data, only: %i[index]
    resources :static_data_auth, only: %i[index]

    # inquiries
    get '/inquiries', to: 'inquiries#index'
    get '/inquiries/:id', to: 'inquiries#show'
    get '/inquiries/:id/status', to: 'inquiries#status'
    get '/download_attachment', to: 'inquiries#download_attachment'
    get '/profile', to: 'inquiries#profile'
    post '/inquiries/auth', to: 'inquiries#create'
    post '/inquiries', to: 'inquiries#unauth_create'
    post '/upload_attachment', to: 'inquiries#upload_attachment'
    post '/inquiries/:id/reply/new', to: 'inquiries#create_reply'
    post '/test_create', to: 'inquiries#test_create'

    # static_data
    get '/categories', to: 'static_data#categories'
    get '/categories/:category_id/topics', to: 'static_data#topics'
    get '/topics/:topic_id/subtopics', to: 'static_data#subtopics'
    get '/zipcodes', to: 'static_data#zipcodes'
    get '/states', to: 'static_data#states'
    get '/optionset', to: 'static_data#optionset'
    get '/announcements', to: 'static_data#announcements'

    # address_validation
    post '/address_validation', to: 'address_validation#create'

    # health_facilities
    get '/health_facilities', to: 'health_facilities#index'
    get '/health_facilities/:id', to: 'health_facilities#show'
  end
end
