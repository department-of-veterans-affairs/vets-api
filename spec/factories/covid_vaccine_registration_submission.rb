# frozen_string_literal: true

FactoryBot.define do 
  factory :covid_vaccine_registration_submission, class: CovidVaccine::V0::RegistrationSubmission do
    form_data do
      {
        "isIdentityVerified": true,
        "firstName": "Jane",
        "lastName": "Doe",
        "birthDate": "1965-01-01",
        "ssn": "419545182",
        "email": "jane.doe@va.gov",
        "phone": "(111) 222-3333",
        "zipCode": "60601",
        "zipCodeDetails": "Yes",
        "vaccineInterest": "INTERESTED",
      }.to_json

      # isIdentityVerified { true }
      # firstName { 'Jane' }
      # lastName { 'Doe' }
      # birthDate { '1965-01-01' }
      # ssn { '419545182' }
      # email { 'jane.doe@va.gov' }
      # phone "(111) 222-3333"
      # zipCode { '60601' }
      # zipCodeDetails { "Yes" }
      # vaccineInterest { "INTERESTED" }
    end
  end
end
