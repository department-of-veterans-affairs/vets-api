# frozen_string_literal: true

FactoryBot.define do
  factory :va0993, class: 'SavedClaim::EducationBenefits::VA0993', parent: :education_benefits do
    form do
      {
        claimantFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        claimantSocialSecurityNumber: '111223333',
        privacyAgreementAccepted: true
      }.to_json
    end
  end

  # Using ssn.json for the full form. This is referenced in the create_daily_spool_files_spec and I didn't
  # want to disrupt the pattern
  factory :va0993_full_form, class: 'SavedClaim::EducationBenefits::VA0993', parent: :education_benefits do
    form { Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '0993', 'ssn.json').read }
  end
end
