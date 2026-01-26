# frozen_string_literal: true

require 'rails_helper'
require 'common/client/configuration/rest'
require 'ibm/configuration'

RSpec.describe Ibm::Configuration do
  let(:base) { Common::Client::Configuration::REST }
  let(:config) { Ibm::Configuration.send(:new) }
  let(:settings) do
    OpenStruct.new(
      {
        host: 'fake.host',
        path: '/api/validated-forms',
        use_mocks: true,
        version: 'v1'
      }
    )
  end

  before do
    allow(Settings).to receive(:ibm).and_return(settings)
  end

  context 'valid settings' do
    it 'returns settings' do
      expect(config.intake_settings).to eq(settings)
    end

    it 'returns service_path' do
      valid_path = 'https://fake.host/api/validated-forms/v1'
      expect(config.service_path).to eq(valid_path)
    end

    it 'returns use_mocks' do
      expect(config.use_mocks?).to eq(settings.use_mocks)
    end
  end

  context 'expected constants' do
    it 'returns service_name' do
      expect(config.service_name).to eq('MMS')
    end

    it 'returns breakers_error_threshold' do
      expect(config.breakers_error_threshold).to eq(80)
    end
  end

  describe '#connection' do
    it 'creates a Faraday connection' do
      conn = config.connection
      expect(conn).to be_a(Faraday::Connection)
      expect(conn.url_prefix.to_s).to eq(config.service_path)
    end
  end
end
