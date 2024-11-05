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

    # static_data
    get '/categories', to: 'static_data#categories'
    get '/categories/:category_id/topics', to: 'static_data#topics'
    get '/topics/:topic_id/subtopics', to: 'static_data#subtopics'
    get '/contents', to: 'static_data#contents'
    get '/zipcodes', to: 'static_data#zipcodes'
    get '/states', to: 'static_data#states'
    get '/optionset', to: 'static_data#optionset'
    get '/announcements', to: 'static_data#announcements'
    get '/branch_of_service', to: 'static_data#branch_of_service'
    get '/test_endpoint', to: 'static_data#test_endpoint'

    # address_validation
    post '/address_validation', to: 'address_validation#create'

    # health_facilities
    post '/health_facilities', to: 'health_facilities#search'
    get '/health_facilities/:id', to: 'health_facilities#show'

    # education_facilities
    get '/education_facilities/autocomplete', to: 'education_facilities#autocomplete'
    get '/education_facilities/search', to: 'education_facilities#search'
    get '/education_facilities/:id', to: 'education_facilities#show'
    get '/education_facilities/:id/children', to: 'education_facilities#children'
  end
end
