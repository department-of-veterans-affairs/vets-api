# frozen_string_literal: true

FactoryBot.define do
  factory :burial_claim, class: 'SavedClaim::Burial' do
    form_id { '21P-530' }
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'WESLEY',
          last: 'FORD'
        },
        claimantEmail: 'foo@foo.com',
        deathDate: '1989-12-13',
        veteranDateOfBirth: '1986-05-06',
        veteranSocialSecurityNumber: '796043735',
        claimantAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        claimantFullName: {
          first: 'Derrick',
          middle: 'A',
          last: 'Stewart'
        },
        burialAllowance: true,
        plotAllowance: true,
        transportation: true
      }.to_json
    end
  end

  factory :burial_claim_v2, class: 'SavedClaim::Burial' do
    form_id { '21P-530V2' }
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'WESLEY',
          last: 'FORD'
        },
        claimantEmail: 'foo@foo.com',
        deathDate: '1989-12-13',
        veteranDateOfBirth: '1986-05-06',
        veteranSocialSecurityNumber: '796043735',
        claimantAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        claimantFullName: {
          first: 'Derrick',
          middle: 'A',
          last: 'Stewart'
        },
        burialAllowance: true,
        plotAllowance: true,
        transportation: true,
        formV2: true
      }.to_json
    end
  end

  # Bad names that fail the EMMS API regex
  factory :burial_claim_bad_names, class: 'SavedClaim::Burial' do
    form_id { '21P-530' }
    form do
      {
        privacyAgreementAccepted: true,
        veteranFullName: {
          first: 'W.A.',
          last: 'Ford#'
        },
        claimantEmail: 'foo@foo.com',
        deathDate: '1989-12-13',
        veteranDateOfBirth: '1986-05-06',
        veteranSocialSecurityNumber: '796043735',
        claimantAddress: {
          country: 'USA',
          state: 'CA',
          postalCode: '90210',
          street: '123 Main St',
          city: 'Anytown'
        },
        claimantFullName: {
          first: 'William',
          middle: 'A',
          last: 'Ford'
        },
        burialAllowance: true,
        plotAllowance: true,
        transportation: true
      }.to_json
    end
  end
end
