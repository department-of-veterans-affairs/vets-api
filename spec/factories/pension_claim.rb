# frozen_string_literal: true
FactoryGirl.define do
  factory :pension_claim, class: SavedClaim::Pension do
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        gender: 'F',
        veteranDateOfBirth: '1989-12-13',
        veteranSocialSecurityNumber: '111223333',
        veteranAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        }
      }.to_json
    end
  end
end
