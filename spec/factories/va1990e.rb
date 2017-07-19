FactoryGirl.define do
  factory :va1990e, class: SavedClaim::EducationBenefits::VA1990e do
    form({
      benefit: 'chapter33',
      relativeFullName: {
        first: 'Mark',
        last: 'Olson'
      },
      veteranSocialSecurityNumber: '111223333',
      privacyAgreementAccepted: true
    }.to_json)
  end
end

