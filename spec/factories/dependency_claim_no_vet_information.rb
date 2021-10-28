# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_claim_no_vet_information, class: 'SavedClaim::DependencyClaim' do
    form_id { '686C-674' }

    form {
      {
        privacyAgreementAccepted: true,
        dependents_application: {
          veteran_contact_information: {
            veteran_address: {
              country_name: 'USA',
              address_line1: '8200 DOBY LN',
              city: 'PASADENA',
              state_code: 'CA',
              zip_code: '21122'
            },
            phone_number: '1112223333',
            email_address: 'vets.gov.user+228@gmail.com'
          }
        }
      }.to_json
    }
  end
end
