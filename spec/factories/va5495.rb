# frozen_string_literal: true

FactoryBot.define do
  factory :va5495, class: 'SavedClaim::EducationBenefits::VA5495', parent: :education_benefits do
    form {
      {
        relativeFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        benefit: 'chapter35',
        privacyAgreementAccepted: true
      }.to_json
    }
  end

  factory :va5495_with_email, class: 'SavedClaim::EducationBenefits::VA5495', parent: :education_benefits do
    form {
      {
        email: 'email@example.com',
        relativeFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        benefit: 'chapter35',
        privacyAgreementAccepted: true
      }.to_json
    }
  end

  factory :va5495_full_form, class: 'SavedClaim::EducationBenefits::VA5495', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '5495', 'kitchen_sink.json').read }
  end
end
