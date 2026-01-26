# frozen_string_literal: true

require 'rails_helper'
require 'bid/awards/service'
require_relative 'support/current_awards_response'

RSpec.describe BID::Awards::Service do
  let(:user) { create(:evss_user, :loa3) }
  let(:service) { BID::Awards::Service.new(user) }

  include_context 'BID Awards CurrentAwardsResponse'

  describe '#get_awards_pension' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      it 'successfully receives an Award Pension object' do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          response = service.get_awards_pension

          expect(response.status).to eq(200)
          expect(response.body['awards_pension']['is_eligible_for_pension']).to be(true)
          expect(response.body['awards_pension']['is_in_receipt_of_pension']).to be(true)
        end
      end
    end

    context 'with a failed submission' do
      it 'handles missing participant_id error' do
        user_without_participant_id = create(:evss_user, :loa3, participant_id: nil)
        service_without_participant_id = BID::Awards::Service.new(user_without_participant_id)

        expect do
          service_without_participant_id.get_awards_pension
        end.to raise_error(StandardError, 'BID Awards Service requires a participant_id for the user')
      end
    end
  end

  describe '#get_current_awards' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      it 'successfully receives a list of current awards' do
        # Mock the service to return the mock response
        allow(service).to receive(:perform).and_return(
          OpenStruct.new(
            status: 200,
            body: mock_response_body
          )
        )

        response = service.get_current_awards

        expect(response.status).to eq(200)
        expect(response.body).to have_key('award')

        award = response.body['award']
        expect(award['award_type']).to eq('CPL')
        expect(award['award_type_desc']).to eq('Compensation/Pension Live')
        expect(award['beneficiary_id']).to eq(12_960_359)
        expect(award['veteran_id']).to eq(12_960_359)
        expect(award['award_event_list']).to have_key('award_events')
        award_events = award['award_event_list']['award_events']
        expect(award_events).to be_an(Array)
        expect(award_events.length).to be > 0

        first_event = award_events.first
        expect(first_event['award_event_status']).to eq('Authorized')
        expect(first_event['award_event_type']).to eq('S')

        expect(first_event['award_line_list']).to have_key('award_lines')
        award_lines = first_event['award_line_list']['award_lines']
        expect(award_lines).to be_an(Array)
        expect(award_lines.length).to be > 0

        first_line = award_lines.first
        expect(first_line['award_line_type']).to eq('IP')
        expect(first_line['gross_amount']).to eq('462.00')
        expect(first_line['net_amount']).to eq('462.00')
      end
    end

    context 'with a failed submission' do
      it 'raises an error when participant_id is missing' do
        user_without_participant_id = create(:evss_user, :loa3, participant_id: nil)
        service_without_participant_id = BID::Awards::Service.new(user_without_participant_id)

        expect do
          service_without_participant_id.get_current_awards
        end.to raise_error(StandardError, 'BID Awards Service requires a participant_id for the user')
      end
    end
  end

  describe 'participant_id validation' do
    it 'returns the participant_id when present' do
      expect(service.send(:participant_id)).to eq(user.participant_id)
    end

    it 'raises an error if participant_id is missing' do
      user_without_participant_id = create(:evss_user, :loa3, participant_id: nil)
      service_without_participant_id = BID::Awards::Service.new(user_without_participant_id)

      expect do
        service_without_participant_id.send(:participant_id)
      end.to raise_error(StandardError, 'BID Awards Service requires a participant_id for the user')
    end
  end
end
