FactoryGirl.define do
  factory :va5495, class: SavedClaim::EducationBenefits::VA5495, parent: :education_benefits do
    form({
      relativeFullName: {
        first: 'Mark',
        last: 'Olson'
      },
      benefit: 'chapter35',
      privacyAgreementAccepted: true
    }.to_json)
  end
end

