# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/disability/disability_response'

RSpec.describe VAProfile::Disability::DisabilityResponse do
  describe '.from' do
    subject { described_class.from(user, raw_response) }

    let(:user) { build(:user, :loa3) }
    let(:status_code) { 200 }
    let(:combined_service_connected_rating_percentage) { '60' }
    let(:raw_response) do
      double('Faraday::Response',
             status: status_code,
             body: {
               'profile' => {
                 'disability_rating' => {
                   'combined_service_connected_rating_percentage' => combined_service_connected_rating_percentage
                 }
               }
             })
    end

    it 'initializes with the correct disability rating percentage' do
      expect(subject.disability_rating.combined_service_connected_rating_percentage)
        .to eq(combined_service_connected_rating_percentage)
    end

    it 'initializes with the correct status code' do
      expect(subject.status).to eq(status_code)
    end
  end
end
