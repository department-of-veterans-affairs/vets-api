# frozen_string_literal: true

FactoryBot.define do
  factory :va1995, class: SavedClaim::EducationBenefits::VA1995, parent: :education_benefits do
    form({
      veteranFullName: {
        first: 'Mark',
        last: 'Olson'
      },
      veteranSocialSecurityNumber: '111223333',
      benefit: 'transferOfEntitlement',
      privacyAgreementAccepted: true
    }.to_json)

    factory :va1995_full_form do
      form(File.read(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1995', 'kitchen_sink.json')))
    end
  end
end
