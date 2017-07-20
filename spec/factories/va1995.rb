FactoryGirl.define do
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
  end
end

