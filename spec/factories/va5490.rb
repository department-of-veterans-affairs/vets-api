# frozen_string_literal: true

FactoryBot.define do
  factory :va5490, class: 'SavedClaim::EducationBenefits::VA5490', parent: :education_benefits do
    form {
      {
        benefit: 'chapter35',
        relationship: 'child',
        veteranSocialSecurityNumber: '111223333',
        relativeFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        privacyAgreementAccepted: true
      }.to_json
    }
  end
end
