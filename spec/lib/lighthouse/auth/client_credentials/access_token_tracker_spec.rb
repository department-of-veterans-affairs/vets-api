# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/auth/client_credentials/access_token_tracker'

RSpec.describe Auth::ClientCredentials::AccessTokenTracker, type: :model do
  describe '#get_access_token' do
    context 'with blank service_name' do
      it 'returns nil' do
        expect(described_class.get_access_token('')).to eq(nil)
      end
    end

    context 'with cached access_token' do
      it 'returns cached access_token' do
        described_class.set_access_token('fake_service', 'xyz')

        expect(described_class.get_access_token('fake_service')).to eq('xyz')
      end
    end

    context 'cache miss' do
      it 'returns nil' do
        expect(described_class.get_access_token('fake_service')).to eq(nil)
      end
    end
  end
end
