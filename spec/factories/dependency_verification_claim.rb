# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_verification_claim, class: 'SavedClaim::DependencyVerificationClaim' do
    form_id { '21-0538' }

    form {
      {
        dependencyVerification: {
          updateDiaries: true,
          veteranInformation: {
            fullName: {
              first: 'Dardan',
              middleInitial: 'A',
              last: 'Testy'
            },
            ssn: '333224444',
            dateOfBirth: '1964-12-26',
            email: 'vet123@test.com'
          }
        }
      }.to_json
    }
  end
end
