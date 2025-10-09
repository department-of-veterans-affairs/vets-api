# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::BaseClient do
  let(:client) { described_class.new }

  describe '#claim_headers' do
    context 'when environment is non-prod' do
      it 'returns single subscription key header' do
        with_settings(Settings, vsp_environment: 'staging') do
          with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key: 'sub-key') do
            expect(client.send(:claim_headers)).to eq({ 'Ocp-Apim-Subscription-Key' => 'sub-key' })
          end
        end
      end
    end

    context 'when environment is prod' do
      it 'returns both E and S subscription keys' do
        with_settings(Settings, vsp_environment: 'production') do
          with_settings(Settings.check_in.travel_reimbursement_api_v2,
                        e_subscription_key: 'e-key', s_subscription_key: 's-key') do
            expect(client.send(:claim_headers)).to eq({
                                                        'Ocp-Apim-Subscription-Key-E' => 'e-key',
                                                        'Ocp-Apim-Subscription-Key-S' => 's-key'
                                                      })
          end
        end
      end
    end
  end

  describe '#mock_enabled?' do
    it 'returns true when settings.mock is true' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2, mock: true) do
        expect(client.send(:mock_enabled?)).to be(true)
      end
    end

    it 'returns true when flipper flag is enabled' do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(true)
      with_settings(Settings.check_in.travel_reimbursement_api_v2, mock: false) do
        expect(client.send(:mock_enabled?)).to be(true)
      end
    end

    it 'returns false otherwise' do
      allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
      with_settings(Settings.check_in.travel_reimbursement_api_v2, mock: false) do
        expect(client.send(:mock_enabled?)).to be(false)
      end
    end
  end

  describe '#config' do
    it 'returns a TravelClaim::Configuration instance' do
      expect(client.config).to be_an_instance_of(TravelClaim::Configuration)
    end
  end

  describe 'inheritance' do
    it 'inherits from Common::Client::Base' do
      expect(described_class.superclass).to eq(Common::Client::Base)
    end
  end
end
