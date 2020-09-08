# frozen_string_literal: true

require 'rails_helper'
require_relative '../../app/services/health_quest/configuration'

class MyErrClass
end

class MyLoggingClass
end

Faraday::Response.register_middleware health_quest_errors: MyErrClass
Faraday::Response.register_middleware health_quest_logging: MyLoggingClass

describe HealthQuest::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(HealthQuest::Configuration.instance.service_name).to eq('HEALTHQUEST')
    end
  end

  describe '#rsa key' do
    it 'has a rsa key' do
      mykey = OpenSSL::PKey::RSA.new(2048)
      allow(File).to receive(:read).and_return(mykey)
      expect(HealthQuest::Configuration.instance.rsa_key.to_text.length).to be > 100
    end
  end

  describe '#faraday connections' do
    before do
      # LJG NOTE: this is just to increase code coverage area for simplecov gem
      @hq_debug_prev = ENV['HEALTH_QUEST_DEBUG']
      ENV['HEALTH_QUEST_DEBUG'] = 'true'
      Faraday::Connection.any_instance.stub(:use).and_return('xyz')
    end

    after do
      if @hq_debug_prev.nil?
        ENV.delete('HEALTH_QUEST_DEBUG')
      else
        ENV['HEALTH_QUEST_DEBUG'] = @hq_debug_prev
      end
    end

    it 'has a faraday connection that returns a header with agent' do
      expect(HealthQuest::Configuration.instance.connection.headers['User-Agent']).to eq('Vets.gov Agent')
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.va_mobile.mock is true' do
      before { Settings.hqva_mobile.mock = 'true' }

      it 'returns true' do
        expect(HealthQuest::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.va_mobile.mock is false' do
      before { Settings.hqva_mobile.mock = 'false' }

      it 'returns false' do
        expect(HealthQuest::Configuration.instance).not_to be_mock_enabled
      end
    end
  end

  describe '#read_timeout' do
    it 'has a default timeout of 15 seconds' do
      expect(HealthQuest::Configuration.instance.read_timeout).to eq(15)
    end
  end
end
