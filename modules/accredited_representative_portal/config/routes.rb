# frozen_string_literal: true

AccreditedRepresentativePortal::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'user', to: 'representative_users#show'

    post 'form21a', to: 'form21a#submit'
    post 'form21a/attachments', to: 'form21a#create_attachment'
    resources :in_progress_forms, only: %i[update show destroy]

    post '/submit_representative_form', to: 'representative_form_upload#submit'
    post '/representative_form_upload', to: 'representative_form_upload#upload_scanned_form'
    post '/upload_supporting_documents', to: 'representative_form_upload#upload_supporting_documents'
    resources :claim_submissions, only: :index

    resources :power_of_attorney_requests, only: %i[index show] do
      resource :decision, only: :create, controller: 'power_of_attorney_request_decisions'
    end

    namespace :claimant do
      post 'search'
    end

    resources :intent_to_file, only: %i[show create]
  end
end
