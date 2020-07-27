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
  factory :va10203_full_form do
    form { File.read(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10203', 'kitchen_sink.json')) }
  end
end
