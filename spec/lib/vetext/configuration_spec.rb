# frozen_string_literal: true

require 'rails_helper'
require 'vetext/configuration'

describe 'VEText::Configuration' do
  subject { VEText::Configuration.instance }

  describe '#base_url' do
    it 'returns the value from the env settings' do
      expect(subject.base_path).to eq('https://vetext1.r01.med.va.gov')
    end
  end

  describe '#service_name' do
    it 'overrides service_name with a unique name' do
      expect(subject.service_name).to eq('VEText')
    end
  end

  describe '#connection' do
    it 'returns a faraday connection' do
      expect(subject.connection).to be_a(Faraday::Connection)
    end
  end
end
