# frozen_string_literal: true

FactoryBot.define do
  factory :va1990n, class: 'SavedClaim::EducationBenefits::VA1990n', parent: :education_benefits do
    form {
      {
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        privacyAgreementAccepted: true
      }.to_json
    }
  end

  factory :va1990n_full_form, class: 'SavedClaim::EducationBenefits::VA1990n', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '1990n', 'kitchen_sink.json').read }
  end
end
