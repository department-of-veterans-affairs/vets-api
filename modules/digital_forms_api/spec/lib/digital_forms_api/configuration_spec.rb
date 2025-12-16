# frozen_string_literal: true

require 'rails_helper'
require 'digital_forms_api/configuration'

RSpec.describe DigitalFormsApi::Configuration do
  let(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default base_url' do
      expect(config.base_url).to eq('https://api.digitalforms.example.com')
    end

    it 'sets default api_key to nil' do
      expect(config.api_key).to be_nil
    end

    it 'sets default timeout to 60 seconds' do
      expect(config.timeout).to eq(60)
    end
  end

  describe 'attribute accessors' do
    it 'allows setting base_url' do
      config.base_url = 'https://new.url.com'
      expect(config.base_url).to eq('https://new.url.com')
    end

    it 'allows setting api_key' do
      config.api_key = 'test_key'
      expect(config.api_key).to eq('test_key')
    end

    it 'allows setting timeout' do
      config.timeout = 120
      expect(config.timeout).to eq(120)
    end
  end
end
