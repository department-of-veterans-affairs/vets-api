# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InheritedProofing::MHVIdentityData, type: :model do
  let(:mhv_identity_data) { InheritedProofing::MHVIdentityData.new(user_uuid:, code:, data:) }
  let(:user_uuid) { SecureRandom.uuid }
  let(:code) { SecureRandom.hex }
  let(:data) do
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
  let(:error) { Common::Exceptions::ValidationErrors }
  let(:error_message) { 'Validation error' }

  describe 'validations' do
    context 'user_uuid' do
      let(:user_uuid) { nil }

      it 'will return validation error if nil' do
        expect { mhv_identity_data.save! }.to raise_error(error, error_message)
      end
    end

    context 'code' do
      let(:code) { nil }

      it 'will return validation error if nil' do
        expect { mhv_identity_data.save! }.to raise_error(error, error_message)
      end
    end

    context 'data' do
      let(:data) { nil }

      it 'will return error message if nil' do
        expect { mhv_identity_data.save! }.to raise_error(error, error_message)
      end
    end
  end
end
