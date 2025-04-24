# frozen_string_literal: true

MyHealth::Engine.routes.draw do
  namespace :v2 do
    scope :medical_records do
      resources :labs_and_tests, only: %i[index], defaults: { format: :json }
    end
  end

  namespace :v1 do
    resources :tooltips, only: %i[index create update], controller: 'tooltips', defaults: { format: :json }

    scope :medical_records do
      resources :vaccines, only: %i[index show], defaults: { format: :json } do
        get :pdf, on: :collection
      end
      resources :allergies, only: %i[index show], defaults: { format: :json }
      resources :clinical_notes, only: %i[index show], defaults: { format: :json }
      resources :labs_and_tests, only: %i[index show], defaults: { format: :json }
      resources :vitals, only: %i[index], defaults: { format: :json }
      resources :conditions, only: %i[index show], defaults: { format: :json }
    end

    namespace :medical_records do
      resources :session, only: %i[create], controller: 'mr_session', defaults: { format: :json } do
        get :status, on: :collection
      end
      resources :ccd, only: [] do
        collection do
          get :generate, to: 'ccd#generate'
          get :download, to: 'ccd#download'
        end
      end
      resources :bbmi_notification, only: [] do
        get :status, on: :collection
      end
      resources :military_service, only: %i[index]
      resources :self_entered, only: %i[index], defaults: { format: :json } do
        get :vitals, on: :collection
        get :allergies, on: :collection
        get :family_history, on: :collection
        get :vaccines, on: :collection
        get :test_entries, on: :collection
        get :medical_events, on: :collection
        get :military_history, on: :collection
        get :providers, on: :collection
        get :health_insurance, on: :collection
        get :treatment_facilities, on: :collection
        get :food_journal, on: :collection
        get :activity_journal, on: :collection
        get :medications, on: :collection
        get :emergency_contacts, on: :collection
      end
      resources :patient, only: %i[index] do
        get :demographic, on: :collection
      end
      resources :imaging, only: %i[index], defaults: { format: :json } do
        get 'request', on: :member, action: :request_download
        get :status, on: :collection, action: :request_status
        get :images, on: :member
        get 'images/:series_id/:image_id', to: 'imaging#image', on: :member, as: :image
        get :dicom, on: :member
      end
      resources :radiology, only: %i[index], defaults: { format: :json }
    end

    scope :messaging do
      resources :triage_teams, only: [:index], defaults: { format: :json }, path: 'recipients'
      resources :all_triage_teams, only: [:index], defaults: { format: :json }, path: 'allrecipients'

      resources :folders, only: %i[index show create update destroy], defaults: { format: :json } do
        resources :messages, only: [:index], defaults: { format: :json }
        resources :threads, only: [:index], defaults: { format: :json }
        post :search, on: :member
      end

      resources :threads, defaults: { format: :json } do
        patch :move, on: :member
      end

      resources :messages, only: %i[show create destroy], defaults: { format: :json } do
        get :thread, on: :member
        get :categories, on: :collection
        get :signature, on: :collection
        patch :move, on: :member
        post :reply, on: :member
        resources :attachments, only: [:show], defaults: { format: :json }
      end

      resources :message_drafts, only: %i[create update], defaults: { format: :json } do
        post ':reply_id/replydraft', on: :collection, action: :create_reply_draft, as: :create_reply
        put ':reply_id/replydraft/:draft_id', on: :collection, action: :update_reply_draft, as: :update_reply
      end

      resource :preferences, only: %i[show update], controller: 'messaging_preferences' do
        post 'recipients', action: :update_triage_team_preferences
        get :signature, on: :member
        post :signature, on: :member, action: :update_signature
      end
    end

    resources :prescriptions, only: %i[index show], defaults: { format: :json } do
      get :active, to: 'prescriptions#index', on: :collection, defaults: { refill_status: 'active' }
      patch :refill, to: 'prescriptions#refill', on: :member
      patch :refill_prescriptions, to: 'prescriptions#refill_prescriptions', on: :collection
      get :list_refillable_prescriptions, to: 'prescriptions#list_refillable_prescriptions', on: :collection
      get 'get_prescription_image/:cmopNdcNumber', to: 'prescriptions#get_prescription_image', on: :collection
      get :documentation, to: 'prescription_documentation#index', on: :member
      resources :trackings, only: :index, controller: :trackings
      collection do
        resource :preferences, only: %i[show update], controller: 'prescription_preferences'
      end
    end

    resource :health_records, only: [:create], defaults: { format: :json } do
      get :refresh, to: 'health_records#refresh', on: :collection
      get :eligible_data_classes, to: 'health_records#eligible_data_classes', on: :collection
      get :show, controller: 'health_record_contents', on: :collection
      post 'sharing/optin', to: 'health_records#optin', on: :collection
      post 'sharing/optout', to: 'health_records#optout', on: :collection
      get 'sharing/status', to: 'health_records#status', on: :collection
    end
  end

  get 'apidocs', to: 'apidocs#index'
end
