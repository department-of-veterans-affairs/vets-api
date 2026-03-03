# frozen_string_literal: true

VRE::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    resources :claims, only: [:create]
    resource :ch31_eligibility_status, only: [:show]
    resource :ch31_case_details, only: [:show]
    resource :ch31_case_milestones, only: [:create]
    resource :case_get_document, only: [:create], controller: 'case_get_document'
  end
end
