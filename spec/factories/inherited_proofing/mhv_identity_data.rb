# frozen_string_literal: true

FactoryBot.define do
  factory :mhv_identity_data, class: 'InheritedProofing::MHVIdentityData' do
    user_uuid { SecureRandom.uuid }
    code { SecureRandom.hex }
    data do
      {
        'mhvId': 19031505, # rubocop:disable Style/NumericLiterals
        'identityProofedMethod': 'IPA',
        'identityProofingDate': '2020-12-14',
        'identityDocumentExist': true,
        'identityDocumentInfo': {
          'primaryIdentityDocumentNumber': '73029213',
          'primaryIdentityDocumentType': 'StateIssuedId',
          'primaryIdentityDocumentCountry': 'United States',
          'primaryIdentityDocumentExpirationDate': '2026-03-30'
        }
      }
    end
  end
end
