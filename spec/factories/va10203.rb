# frozen_string_literal: true

FactoryBot.define do
  factory :va10203, class: SavedClaim::EducationBenefits::VA10203, parent: :education_benefits do
    form {
      {
        veteranFullName: {
          first: 'Mark',
          last: 'Olson'
        },
        veteranSocialSecurityNumber: '111223334',
        benefit: 'transferOfEntitlement',
        isEnrolledStem: true,
        isPursuingTeachingCert: true,
        benefitLeft: 'moreThanSixMonths',
        degreeName: 'Degree Name',
        schoolName: 'School Name',
        schoolCity: 'Test',
        schoolState: 'TN',
        isActiveDuty: true,
        veteranAddress: {
          city: 'Milwaukee',
          country: 'USA',
          postalCode: '53130',
          state: 'WI',
          street: '123 Main St'
        },
        email: 'test@sample.com',
        mobilePhone: '5551110001',
        bankAccount: {
          accountNumber: '88888888888',
          accountType: 'checking',
          bankName: 'First Bank of JSON',
          routingNumber: '123456789'
        },
        privacyAgreementAccepted: true
      }.to_json
    }
  end
  factory :va10203_full_form do
    form { File.read(Rails.root.join('spec', 'fixtures', 'education_benefits_claims', '10203', 'kitchen_sink.json')) }
  end
end
