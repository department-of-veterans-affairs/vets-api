# frozen_string_literal: true

FactoryBot.define do
  factory :employment_questionairres_claim, class: 'EmploymentQuestionairres::SavedClaim' do
    form_id { 'VBA-21-4140-ARE' }
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
