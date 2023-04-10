# frozen_string_literal: true

FactoryBot.define do
  factory :va1990e, class: 'SavedClaim::EducationBenefits::VA1990e', parent: :education_benefits do
    form {
      {
        benefit: 'chapter33',
        relativeFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        veteranSocialSecurityNumber: '111223333',
        privacyAgreementAccepted: true
      }.to_json
    }
  end

  factory :va1990e_with_email, class: 'SavedClaim::EducationBenefits::VA1990e', parent: :education_benefits do
    form {
      {
        email: 'email@example.com',
        benefit: 'chapter33',
        relativeFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        veteranSocialSecurityNumber: '111223333',
        privacyAgreementAccepted: true
      }.to_json
    }
  end
end
