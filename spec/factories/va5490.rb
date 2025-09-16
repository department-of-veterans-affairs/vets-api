# frozen_string_literal: true

FactoryBot.define do
  factory :va5490, class: 'SavedClaim::EducationBenefits::VA5490', parent: :education_benefits do
    form {
      {
        email: 'email@example.com',
        benefit: 'chapter35',
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
        veteranSocialSecurityNumber: '111223333',
        relativeFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        privacyAgreementAccepted: true
      }.to_json
    }
  end

  factory :va5490_full_form, class: 'SavedClaim::EducationBenefits::VA5490', parent: :education_benefits do
    form {
      Rails.root.join(
        'spec', 'fixtures', 'education_benefits_claims', '5490', 'kitchen_sink_chapter_35_spouse.json'
      ).read
    }
  end
end
