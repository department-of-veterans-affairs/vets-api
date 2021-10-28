# frozen_string_literal: true

FactoryBot.define do
  factory :pension_claim, class: 'SavedClaim::Pension' do
    form_id { '21P-527EZ' }
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        gender: 'F',
        email: 'foo@foo.com',
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
