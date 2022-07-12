# frozen_string_literal: true

MebApi::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'claimant_info', to: 'education_benefits#claimant_info'
    get 'service_history', to: 'education_benefits#service_history'
    get 'eligibility', to: 'education_benefits#eligibility'
    get 'claim_status', to: 'education_benefits#claim_status'
    get 'claim_letter', to: 'education_benefits#claim_letter'
    get 'toe_letter', to: 'education_benefits#toe_letter'
    post 'submit_claim', to: 'education_benefits#submit_claim'
    get 'enrollment', to: 'education_benefits#enrollment'
    post 'submit_enrollment_verification', to: 'education_benefits#submit_enrollment_verification'

    post 'sponsors', to: 'toes#sponsors'
    post 'fry_dea_sponsors', to: 'fry_dea#sponsors'
    get 'claim_letter/fry', to: 'fry_dea#claim_letter'

    get 'apidocs', to: 'apidocs#index'
  end
end
