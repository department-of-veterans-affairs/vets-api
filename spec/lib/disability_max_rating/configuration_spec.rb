# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DisabilityMaxRating::Configuration do
  subject { described_class.new }

  describe '#base_path' do
    it 'returns the correct base URL from the settings' do
      expect(subject.base_path).to eq(Settings.disability_max_ratings_api.url.to_s)
    end
  end

  describe '#service_name' do
    it 'returns the DisabilityMaxRatingClient service name' do
      expect(subject.service_name).to eq('DisabilityMaxRatingClient')
    end
  end

  describe '#connection' do
    it 'builds a Faraday connection' do
      connection = subject.connection
      expect(connection.builder.handlers).to include(Faraday::Response::RaiseError)
      expect(connection.builder.handlers).to include(Faraday::Adapter::NetHttp)
    end
  end
end
