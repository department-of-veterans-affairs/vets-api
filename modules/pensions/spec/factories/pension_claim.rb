# frozen_string_literal: true

FactoryBot.define do
  factory :pensions_module_pension_claim, class: 'Pensions::SavedClaim' do
    form_id { '21P-527EZ' }
    form do
      {
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        email: 'foo@foo.com',
        veteranDateOfBirth: '1989-12-13',
        veteranSocialSecurityNumber: '111223333',
        veteranAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        statementOfTruthCertified: true,
        statementOfTruthSignature: 'Test User'
      }.to_json
    end
  end
end
