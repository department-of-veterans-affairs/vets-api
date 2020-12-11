# frozen_string_literal: true

FactoryBot.define do 
  factory :covid_vaccine_registration_submission, class: CovidVaccine::V0::RegistrationSubmission do
    form_data do
      {
        isIdentityVerified: { true }
        firstName: { nil }
        lastName: { nil }
        birthDate: { nil }
        ssn: { nil }
        email: { nil }
        phone: "(111) 222-3333"
        zipCode: { nil }
        zipCodeDetails: { "Yes" }
        vaccineInterest: { "INTERESTED" }
      }.to_json
    end
  end
end
