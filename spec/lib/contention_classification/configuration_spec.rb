# frozen_string_literal: true

require 'rails_helper'
require 'contention_classification/client'

RSpec.describe ContentionClassification::Configuration do
  subject { described_class.send(:new) }

  describe '#base_path' do
    it 'returns the correct base path' do
      expect(subject.base_path).to eq(Settings.contention_classification_api.url.to_s)
    end
  end

  describe '#service_name' do
    it 'returns the correct service name' do
      expect(subject.service_name).to eq('ContentionClassificationApiClient')
    end
  end

  describe '#connection' do
    it 'instantiates a Faraday client with correct settings' do
      connection = subject.connection
      expect(connection).to be_instance_of(Faraday::Connection)
      expect(connection.url_prefix.to_s).to eq(subject.base_path)
      expect(connection.options.timeout).to eq(Settings.contention_classification_api.read_timeout)
      expect(connection.options.open_timeout).to eq(Settings.contention_classification_api.open_timeout)
    end

    it 'includes the correct middleware' do
      connection = subject.connection
      expect(connection.builder.handlers).to include(Faraday::Response::RaiseError)
      expect(connection.builder.handlers).to include(Faraday::Response::Json)
    end
  end
end
