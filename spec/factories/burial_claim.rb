# frozen_string_literal: true
FactoryBot.define do
  factory :burial_claim, class: SavedClaim::Burial do
    form_id '21P-530'
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'Test',
          last: 'User'
        },
        claimantEmail: 'foo@foo.com',
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
