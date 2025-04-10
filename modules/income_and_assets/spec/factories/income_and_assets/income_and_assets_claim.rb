# frozen_string_literal: true

FactoryBot.define do
  factory :income_and_assets_claim, class: 'IncomeAndAssets::SavedClaim' do
    form_id { '21P-0969' }
    form do
      {
        veteranFullName: {
          first: 'John',
          middle: 'Edmund',
          last: 'Doe'
        },
        veteranSocialSecurityNumber: '333224444',
        statementOfTruthCertified: true,
        statementOfTruthSignature: 'John Edmund Doe'
      }.to_json
    end
  end
end
