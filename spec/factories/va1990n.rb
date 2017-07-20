FactoryGirl.define do
  factory :va1990n, class: SavedClaim::EducationBenefits::VA1990n do
    form({
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        privacyAgreementAccepted: true
      }.to_json
    )
  end
end
