# frozen_string_literal: true

FactoryBot.define do
  factory :covid_vaccine_registration_submission, class: 'CovidVaccine::V0::RegistrationSubmission' do
    sid { SecureRandom.uuid }
    account_id { SecureRandom.uuid }

    form_data {
      {
        vaccine_interest: 'INTERESTED',
        zip_code: '97212',
        time_at_zip: 'YES',
        phone: '808-555-1212',
        email: 'foo@example.com',
        first_name: 'Jon',
        last_name: 'Doe',
        date_of_birth: '1900-01-01'
      }
    }
  end
end
