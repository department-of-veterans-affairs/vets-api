# frozen_string_literal: true

FactoryBot.define do
  factory :dependents_verification_claim, class: 'DependentsVerification::SavedClaim' do
    transient do
      veteran_ssn { nil }
    end

    form_id { '21-0538' }
    form do
      form_data = {
        veteranInformation: {
          fullName: {
            first: 'Jane',
            middle: 'Elizabeth',
            last: 'Maximal'
          },
          birthDate: '2020-01-01',
          ssnLastFour: '4445'
        },
        address: {
          addressType: 'DOMESTIC',
          street: '123 Main St',
          unitNumber: '4B',
          city: 'Anytown',
          state: 'NY',
          postalCode: '12345-1234',
          country: 'USA'
        },
        dependents: [
          {
            awardIndicator: 'Y',
            dateOfBirth: '07/07/1970',
            firstName: 'SPOUSY',
            gender: 'F',
            lastName: 'FOSTER',
            proofOfDependency: 'N',
            ptcpntId: '600055042',
            relatedToVet: 'Y',
            relationship: 'Spouse',
            ssn: '3332',
            ssnVerifyStatus: '0',
            veteranIndicator: 'N',
            dob: 'July 7, 1970',
            fullName: 'SPOUSY FOSTER',
            age: 55,
            removalDate: ''
          }
        ],
        hasDependentsStatusChanged: 'N',
        email: 'maximal@example.com',
        phone: '5551234567',
        internationalPhone: '15552229999',
        electronicCorrespondence: 'true',
        statementOfTruthSignature: 'Jane Elizabeth Maximal',
        statementOfTruthCertified: true
      }

      # Add SSN if provided
      form_data[:veteranInformation][:ssn] = veteran_ssn

      form_data.to_json
    end

    trait :pending do
      after(:create) do |claim|
        create(:lighthouse_submission, :pending, saved_claim_id: claim.id)
      end
    end

    trait :submitted do
      after(:create) do |claim|
        create(:lighthouse_submission, :submitted, saved_claim_id: claim.id)
      end
    end

    trait :failure do
      after(:create) do |claim|
        create(:lighthouse_submission, :failure, saved_claim_id: claim.id)
      end
    end
  end
end
