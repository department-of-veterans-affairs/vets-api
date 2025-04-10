# frozen_string_literal: true

AccreditedRepresentativePortal::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'user', to: 'representative_users#show'

    ##
    # While these endpoints are still under development, they should be
    # inaccessible in production. For now, this check is extra stringent, and
    # makes these endpoints inaccessible anywhere outside development and test.
    # But once development on these features picks back up, we want them to be
    # accessible in staging too.
    #
    # TODO: Carry out this per-environment guard of these endpoints by using
    # Flipper feature toggling and controller before actions instead.
    #
    if Rails.env.development? || Rails.env.test?
      post 'form21a', to: 'form21a#submit'
      resources :in_progress_forms, only: %i[update show destroy]
    end

    post '/submit_representative_form', to: 'representative_form_upload#submit'
    post '/representative_form_upload', to: 'representative_form_upload#upload_scanned_form'

    resources :power_of_attorney_requests, only: %i[index show] do
      resource :decision, only: :create, controller: 'power_of_attorney_request_decisions'
    end

    namespace :claimant do
      post 'power_of_attorney_requests', to: 'power_of_attorney_requests#index'
    end

    resources :intent_to_file, only: %i[show create]
  end
end
