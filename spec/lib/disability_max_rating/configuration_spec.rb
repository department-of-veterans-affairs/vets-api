# frozen_string_literal: true

require 'rails_helper'
require 'disability_max_rating/configuration'

RSpec.describe DisabilityMaxRating::Configuration do
  subject { described_class.send(:new) }

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
    it 'includes the correct middleware and uses the configured base path' do
      connection = subject.connection

      expect(connection.builder.handlers).to include(Faraday::Response::RaiseError)
      expect(connection.builder.handlers).to include(Faraday::Response::Json)
    end
  end
end
