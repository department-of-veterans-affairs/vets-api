# frozen_string_literal: true

FactoryBot.define do
  factory :va10203, class: SavedClaim::EducationBenefits::VA10203, parent: :education_benefits do
    form {
      {
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        veteranSocialSecurityNumber: '111223334',
        benefit: 'transferOfEntitlement',
        isEdithNourseRogersScholarship: true,
        privacyAgreementAccepted: true
      }.to_json
    }
  end
end
