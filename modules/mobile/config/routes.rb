# frozen_string_literal: true

Mobile::Engine.routes.draw do
  get '/', to: 'discovery#welcome'

  namespace :v0 do
    get '/appeal/:id', to: 'claims_and_appeals#get_appeal'
    get '/appointment_requests/:appointment_request_id/messages', to: 'appointment_request_messages#index'
    get '/appointments', to: 'appointments#index'
    put '/appointments/cancel/:id', to: 'appointments#cancel'
    get '/claims-and-appeals-overview', to: 'claims_and_appeals#index'
    get '/claim/:id', to: 'claims_and_appeals#get_claim'
    post '/claim/:id/documents', to: 'claims_and_appeals#upload_document'
    post '/claim/:id/documents/multi-image', to: 'claims_and_appeals#upload_multi_image_document'
    post '/claim/:id/request-decision', to: 'claims_and_appeals#request_decision'
    get '/disability-rating', to: 'disability_rating#index'
    get '/health/immunizations', to: 'immunizations#index'
    get '/health/locations/:id', to: 'locations#show'
    get '/letters', to: 'letters#index'
    get '/letters/beneficiary', to: 'letters#beneficiary'
    post '/letters/:type/download', to: 'letters#download'
    get '/maintenance_windows', to: 'maintenance_windows#index'
    get '/messaging/health/messages/signature', to: 'messages#signature'
    get '/military-service-history', to: 'military_information#get_service_history'
    get '/payment-history', to: 'payment_history#index'
    get '/payment-information/benefits', to: 'payment_information#index'
    put '/payment-information/benefits', to: 'payment_information#update'
    put '/push/register', to: 'push_notifications#register'
    get '/push/prefs/:endpoint_sid', to: 'push_notifications#get_prefs'
    put '/push/prefs/:endpoint_sid', to: 'push_notifications#set_pref'
    post '/push/send', to: 'push_notifications#send_notification'
    get '/user', to: 'users#show'
    get '/user/logout', to: 'users#logout'
    post '/user/addresses', to: 'addresses#create'
    put '/user/addresses', to: 'addresses#update'
    delete '/user/addresses', to: 'addresses#destroy'
    post '/user/addresses/validate', to: 'addresses#validate'
    post '/user/emails', to: 'emails#create'
    put '/user/emails', to: 'emails#update'
    delete '/user/emails', to: 'emails#destroy'
    post '/user/phones', to: 'phones#create'
    put '/user/phones', to: 'phones#update'
    delete '/user/phones', to: 'phones#destroy'

    scope :messaging do
      scope :health do
        resources :triage_teams, only: [:index], defaults: { format: :json }, path: 'recipients'

        resources :folders, only: %i[index show create destroy], defaults: { format: :json } do
          resources :messages, only: [:index], defaults: { format: :json }
        end

        resources :messages, only: %i[show create destroy], defaults: { format: :json } do
          get :thread, on: :member
          get :categories, on: :collection
          patch :move, on: :member
          post :reply, on: :member
          resources :attachments, only: [:show], defaults: { format: :json }
        end

        resources :message_drafts, only: %i[create update], defaults: { format: :json } do
          post ':reply_id/replydraft', on: :collection, action: :create_reply_draft, as: :create_reply
          put ':reply_id/replydraft/:draft_id', on: :collection, action: :update_reply_draft, as: :update_reply
        end
      end
    end
  end

  namespace :v1 do
    get '/health/immunizations', to: 'immunizations#index'
    get '/user', to: 'users#show'
  end
end
