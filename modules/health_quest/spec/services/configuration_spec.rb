# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Configuration do
  describe '#service_name' do
    it 'has a service name' do
      expect(HealthQuest::Configuration.instance.service_name).to eq('HEALTHQUEST')
    end
  end

  describe '#connection' do
    before do
      @hq_debug_prev = ENV['HEALTH_QUEST_DEBUG']
      ENV['HEALTH_QUEST_DEBUG'] = 'true'
    end

    after do
      if @hq_debug_prev.nil?
        ENV.delete('HEALTH_QUEST_DEBUG')
      else
        ENV['HEALTH_QUEST_DEBUG'] = @hq_debug_prev
      end
    end

    it 'returns a connection' do
      expect(HealthQuest::Configuration.instance.connection).not_to be_nil
    end
  end

  describe '#mock_enabled?' do
    context 'when Settings.hqva_mobile.mock is true' do
      before { Settings.hqva_mobile.mock = 'true' }

      it 'returns true' do
        expect(HealthQuest::Configuration.instance).to be_mock_enabled
      end
    end

    context 'when Settings.hqva_mobile.mock is false' do
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
