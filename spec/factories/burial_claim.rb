# frozen_string_literal: true
FactoryGirl.define do
  factory :burial_claim, class: SavedClaim::Burial do
    form do
      {
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        deathDate: '1989-12-13',
        veteranSocialSecurityNumber: '111223333',
        claimantAddress: {
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
