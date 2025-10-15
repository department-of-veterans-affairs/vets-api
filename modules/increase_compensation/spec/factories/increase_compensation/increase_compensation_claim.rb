# frozen_string_literal: true

FactoryBot.define do
  factory :increase_compensation_claim, class: 'IncreaseCompensation::SavedClaim' do
    form_id { '21P-8416' }
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
