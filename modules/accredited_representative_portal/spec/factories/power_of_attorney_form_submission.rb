# frozen_string_literal: true

FactoryBot.define do
  factory :power_of_attorney_form_submission,
          class: 'AccreditedRepresentativePortal::PowerOfAttorneyFormSubmission' do
    association :power_of_attorney_request
    service_id { SecureRandom.uuid }
    service_response { '{}' }
    status { :enqueue_succeeded }
    status_updated_at { DateTime.now }
  end
end
