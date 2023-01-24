# frozen_string_literal: true

FactoryBot.define do
  factory :va5490, class: 'SavedClaim::EducationBenefits::VA5490', parent: :education_benefits do
    form {
      {
        email: 'email@example.com',
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

  factory :va5490_chapter33, class: 'SavedClaim::EducationBenefits::VA5490', parent: :education_benefits do
    form {
      {
        email: 'email@example.com',
        benefit: 'chapter33',
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
