# frozen_string_literal: true

require 'rails_helper'

describe MockedAuthentication::CredentialInfo do
  let(:mock_credential_info) { build(:mock_credential_info, credential_info_code:) }
  let(:credential_info_code) { SecureRandom.hex }

  describe '#validate' do
    context 'without a credential_info_code' do
      let(:credential_info_code) { nil }

      it 'does not validate' do
        expect(mock_credential_info).not_to be_valid
      end
    end

    context 'with a credential_info_code' do
      it 'validates' do
        expect(mock_credential_info).to be_valid
      end
    end
  end
end
