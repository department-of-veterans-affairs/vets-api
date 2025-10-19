# frozen_string_literal: true

AccreditedRepresentativePortal::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'authorize_as_representative', to: 'representative_users#authorize_as_representative'
    get 'user', to: 'representative_users#show'

    # Form 21a routes
    post 'form21a', to: 'form21a#submit'

    scope 'form21a' do
      post ':details_slug', to: 'form21a#details', constraints: {
        details_slug: /
          (?:conviction-details|
             court-martialed-details|
             under-charges-details|
             resigned-from-education-details|
             withdrawn-from-education-details|
             disciplined-for-dishonesty-details|
             resigned-for-dishonesty-details|
             representative-for-agency-details|
             reprimanded-in-agency-details|
             resigned-from-agency-details|
             applied-for-va-accreditation-details|
             terminated-by-vsorg-details|
             condition-that-affects-representation-details|
             condition-that-affects-examination-details
          )
        /x
      }
    end

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
