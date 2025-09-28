# frozen_string_literal: true

FactoryBot.define do
  factory :survivors_benefits_claim, class: 'SurvivorsBenefits::SavedClaim' do
    form_id { '21P-534EZ' }
    form do
      {
        veteranFullName: {
          first: 'John',
          middle: 'Edmund',
          last: 'Doe'
        },
        claimantFullName: {
          first: 'Derrick',
          middle: 'A',
          last: 'Stewart'
        },
        veteranSocialSecurityNumber: '333224444',
        statementOfTruthCertified: true,
        statementOfTruthSignature: 'John Edmund Doe'
      }.to_json
    end
  end
end
