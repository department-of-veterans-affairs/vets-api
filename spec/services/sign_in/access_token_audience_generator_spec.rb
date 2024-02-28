# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::AccessTokenAudienceGenerator do
  subject(:generator) { described_class.new(client_config:) }

  describe '#perform' do
    let!(:shared_client1) { create(:client_config, shared_sessions: true) }
    let!(:shared_client2) { create(:client_config, shared_sessions: true) }
    let!(:non_shared_client) { create(:client_config, shared_sessions: false) }

    before do
      Rails.cache.clear
    end

    context 'when the client_id is part of shared session client IDs' do
      let(:client_config) { shared_client1 }
      let(:expected_audience) { [shared_client1.client_id, shared_client2.client_id] }

      it 'returns all shared session client IDs as the audience' do
        expect(generator.perform).to match_array(expected_audience)
      end
    end

    context 'when the client_id is not part of shared session client IDs' do
      let(:client_config) { non_shared_client }
      let(:expected_audience) { [non_shared_client.client_id] }

      it 'returns only the client_id as the audience' do
        expect(generator.perform).to match_array(expected_audience)
      end
    end

    context 'when the shared session client IDs are cached' do
      let(:client_config) { shared_client1 }

      it 'does not query the database' do
        expect(SignIn::ClientConfig).to receive(:where).once.and_call_original

        generator.perform
        generator.perform
      end
    end
  end
end
