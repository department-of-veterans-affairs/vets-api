# frozen_string_literal: true

FactoryBot.define do
  factory :burials_saved_claim, class: 'Burials::SavedClaim' do
    form_id { '21P-530EZ' }
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'WESLEY',
          last: 'FORD'
        },
        claimantEmail: 'foo@foo.com',
        deathDate: '1989-12-13',
        veteranDateOfBirth: '1986-05-06',
        veteranSocialSecurityNumber: '796043735',
        claimantAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        claimantFullName: {
          first: 'Derrick',
          middle: 'A',
          last: 'Stewart'
        },
        burialAllowance: true,
        plotAllowance: true,
        transportation: true
      }.to_json
    end

    trait :pending do
      after(:create) do |claim|
        create(:form_submission, :pending, saved_claim_id: claim.id)
      end
    end

    trait :success do
      after(:create) do |claim|
        create(:form_submission, :success, saved_claim_id: claim.id)
      end
    end

    trait :failure do
      after(:create) do |claim|
        create(:form_submission, :failure, saved_claim_id: claim.id)
      end
    end
  end
end
