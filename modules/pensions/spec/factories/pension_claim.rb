# frozen_string_literal: true

FactoryBot.define do
  factory :pensions_saved_claim, class: 'Pensions::SavedClaim' do
    form_id { '21P-527EZ' }
    # TODO: add this back when the DB migration is done
    # user_account_id { '123567788' }
    form do
      {
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        email: 'foo@foo.com',
        veteranDateOfBirth: '1989-12-13',
        veteranSocialSecurityNumber: '111223333',
        veteranAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        statementOfTruthCertified: true,
        statementOfTruthSignature: 'Test User'
      }.to_json
    end

    trait :pending do
      after(:create) do |pension_claim|
        create(:lighthouse_submission, :pending, saved_claim_id: pension_claim.id)
      end
    end

    trait :submitted do
      after(:create) do |pension_claim|
        create(:lighthouse_submission, :submitted, saved_claim_id: pension_claim.id)
      end
    end

    trait :failure do
      after(:create) do |pension_claim|
        create(:lighthouse_submission, :failure, saved_claim_id: pension_claim.id)
      end
    end
  end
end
