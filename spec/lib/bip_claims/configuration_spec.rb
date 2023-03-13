# frozen_string_literal: true

require 'rails_helper'
require 'bip_claims/configuration'

describe BipClaims::Configuration do
  describe '#base_path' do
    it 'has a base path' do
      expect(BipClaims::Configuration.instance.base_path).to eq(Settings.bip.claims.url)
    end
  end

  describe '#service_name' do
    it 'has a service name' do
      expect(BipClaims::Configuration.instance.service_name).to eq('BipClaims')
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.bip.claims.mock is true' do
      before { allow(Settings.bip.claims).to receive(:mock).and_return('true') }

      it 'returns true' do
        expect(BipClaims::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.caseflow.mock is false' do
      before { allow(Settings.bip.claims).to receive(:mock).and_return('false') }

      it 'returns false' do
        expect(BipClaims::Configuration.instance).not_to be_mock_enabled
      end
    end
  end
end
