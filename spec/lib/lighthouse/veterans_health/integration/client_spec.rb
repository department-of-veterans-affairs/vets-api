# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veterans_health/client'

# rubocop:disable RSpec/FilePath
RSpec.describe Lighthouse::VeteransHealth::Client, :vcr do
  describe '#list_medication_requests' do
    context 'with a multi-page response' do
      subject(:client) { described_class.new(32_000_225).list_medication_requests }

      it 'returns all entries in the response' do
        VCR.use_cassette('lighthouse/veterans_health/medication_requests') do
          expect(subject.body['entry'].count).to match subject.body['total']
        end
      end
    end
  end

  describe '#list_observations' do
    subject(:client) { described_class.new(2_000_163).list_observations }

    it 'returns all sorts of observations' do
      VCR.use_cassette('lighthouse/veterans_health/observations') do
        entries = subject.body['entry']
        expect(entries.count).to match subject.body['total']
        expect(entries.map { |e| e['resource']['code']['coding'].map { |c| c['code'] } })
          .to include(['718-7'], ['777-3'], ['785-6'], ['786-4'], ['787-2'], ['789-8'],
                      ['4544-3'], ['6690-2'], ['8302-2'],
                      ['21000-5'], ['29463-7'], ['32207-3'], ['32623-1'], ['72514-3'], ['85354-9'])
      end
    end
  end
end
# rubocop:enable RSpec/FilePath
