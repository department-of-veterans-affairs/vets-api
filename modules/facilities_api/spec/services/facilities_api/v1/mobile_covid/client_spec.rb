# frozen_string_literal: true

require 'rails_helper'

vcr_options = {
  cassette_name: 'facilities/mobile/covid',
  match_requests_on: %i[path query],
  allow_playback_repeats: true,
  record: :new_episodes
}

RSpec.describe FacilitiesApi::V1::MobileCovid::Client, team: :facilities, vcr: vcr_options do
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
      response = mobile_client.direct_booking_eligibility_criteria_by_id('523A5')
      expect(response.id).to eql('523A5')
    end

    context 'Covid online scheduling is available' do
      it 'checks covid_online_scheduling_available?' do
        response = mobile_client.direct_booking_eligibility_criteria_by_id('523A5')
        expect(response).to be_covid_online_scheduling_available
      end
    end
  end
end
