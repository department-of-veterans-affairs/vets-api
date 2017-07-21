# frozen_string_literal: true
FactoryGirl.define do
  factory :va1990n, class: SavedClaim::EducationBenefits::VA1990n, parent: :education_benefits do
    form({
      veteranFullName: {
        first: 'Mark',
        last: 'Olson'
      },
      privacyAgreementAccepted: true
    }.to_json)
  end
end
