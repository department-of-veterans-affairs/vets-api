# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::Configuration do
  subject { described_class.instance }

  describe '#service_name' do
    it 'has a service name' do
      expect(subject.service_name).to eq('VAOS')
    end
  end

  describe '#base_path' do
    it 'has a base path' do
      expect(subject.base_path).to eq(Settings.va_mobile.url)
    end
  end

  describe '#connection' do
    it 'has a connection' do
      expect(subject.connection).to be_an_instance_of(Faraday::Connection)
    end
  end
end
