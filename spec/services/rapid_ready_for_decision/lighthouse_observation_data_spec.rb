# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

RSpec.describe RapidReadyForDecision::LighthouseObservationData do
  subject { described_class }

  around do |example|
    VCR.use_cassette('rrd/lighthouse_observations', &example)
  end

  let(:response) do
    # Using specific test ICN below:
    client = Lighthouse::VeteransHealth::Client.new(32_000_225)
    client.list_bp_observations
  end

  let(:response_with_recent_bp) do
    original_first_bp_reading = response.body['entry'].first
    original_first_bp_reading['resource']['effectiveDateTime'] = (Time.zone.today - 2.weeks).to_s
    response
  end

  describe '#transform' do
    it 'returns only bp readings from the past year' do
      expect(described_class.new(response_with_recent_bp).transform)
        .to match(
          [
            {
              effectiveDateTime: (Time.zone.today - 2.weeks).to_s,
              practitioner: 'DR. THOMAS359 REYNOLDS206 PHD',
              organization: 'LYONS VA MEDICAL CENTER',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 175.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 111.0,
                'unit' => 'mm[Hg]'
              }
            }
          ]
        )
    end

    it 'returns the expected hash from an empty list' do
      empty_response = OpenStruct.new
      empty_response.body = { 'entry': [] }.with_indifferent_access
      expect(described_class.new(empty_response).transform)
        .to eq([])
    end
  end
end
