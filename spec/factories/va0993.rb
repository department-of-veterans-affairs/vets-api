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
end
