# frozen_string_literal: true

MebApi::Engine.routes.draw do
  namespace :v0, defaults: { format: :json } do
    get 'claimant_info', to: 'education_benefits#claimant_info'
    get 'service_history', to: 'education_benefits#service_history'
    get 'eligibility', to: 'education_benefits#eligibility'
    get 'claim_status', to: 'education_benefits#claim_status'
    get 'claim_letter', to: 'education_benefits#claim_letter'
    post 'submit_claim', to: 'education_benefits#submit_claim'
    get 'enrollment', to: 'education_benefits#enrollment'
    post 'submit_enrollment_verification', to: 'education_benefits#submit_enrollment_verification'

    post 'duplicate_contact_info', to: 'education_benefits#duplicate_contact_info'

    post 'forms_claim_letter', to: 'forms#claim_letter'
    post 'forms_sponsors', to: 'forms#sponsors'
    post 'forms_submit_claim', to: 'forms#submit_claim'
    get 'forms_claimant_info', to: 'forms#claimant_info'
    get 'forms_claim_status', to: 'forms#claim_status'

    get 'apidocs', to: 'apidocs#index'
  end
end
