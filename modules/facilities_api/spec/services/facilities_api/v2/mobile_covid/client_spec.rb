# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/mobile/covid',
  match_requests_on: %i[path query],
  allow_playback_repeats: true
}

RSpec.describe FacilitiesApi::V2::MobileCovid::Client, team: :facilities, vcr: vcr_options do
  let(:mobile_client) { described_class.new }

  context 'with an http timeout' do
    it 'logs an error and raise GatewayTimeout' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
      expect do
        mobile_client.direct_booking_eligibility_criteria_by_id('523A5')
      end.to raise_error(Common::Exceptions::GatewayTimeout)
    end
  end

  describe '#direct_booking_eligibility_criteria_by_id' do
    it 'finds a facility by ID' do
      response = mobile_client.direct_booking_eligibility_criteria_by_id('vha_523A5')
      expect(response.id).to eql('523A5')
    end

    context 'Covid online scheduling is available' do
      it 'checks covid_online_scheduling_available?' do
        response = mobile_client.direct_booking_eligibility_criteria_by_id('vha_523A5')
        expect(response).to be_covid_online_scheduling_available
      end
    end
  end

  describe '#sanitize_id' do
    {
      'vha_523A5' => '523A5',
      'vha_689A4' => '689A4',
      'vha_631' => '631',
      '523A5' => '523A5'
    }.each_pair do |raw_id, expected_id|
      context raw_id do
        subject { mobile_client.sanitize_id(raw_id) }

        it { is_expected.to eql expected_id }
      end
    end
  end
end
