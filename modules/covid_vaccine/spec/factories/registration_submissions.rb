# frozen_string_literal: true

FactoryBot.define do
  factory :covid_vaccine_registration_submission, class: 'CovidVaccine::V0::RegistrationSubmission' do
    sid { SecureRandom.uuid }
    account_id { SecureRandom.uuid }
  end
end
