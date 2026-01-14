# frozen_string_literal: true

require 'rails_helper'
require 'bid/awards/service'
require 'bid/awards/support/current_awards_response'

RSpec.describe BID::Awards::Service do
  let(:user) { create(:evss_user, :loa3) }
  let(:service) { BID::Awards::Service.new(user) }

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
  end

  describe '#get_current_awards' do
    let(:faraday_response) { double('faraday_connection') }

    before do
      allow(faraday_response).to receive(:env)
    end

    context 'with a successful submission' do
      include_context 'BID Awards CurrentAwardsResponse'

      it 'successfully receives a list of current awards' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
          double('response', status: 200, body: mock_response_body, success?: true)
        )

        response = service.get_current_awards

        expect(response.status).to eq(200)
        expect(response.body).to have_key('Award')

        award = response.body['Award']
        expect(award['awardType']).to eq('CPL')
        expect(award['awardTypeDesc']).to eq('Compensation/Pension Live')
        expect(award['beneficiaryID']).to eq(12_960_359)
        expect(award['veteranID']).to eq(12_960_359)

        expect(award['AwardEventList']).to have_key('awardEvents')
        award_events = award['AwardEventList']['awardEvents']
        expect(award_events).to be_an(Array)
        expect(award_events.length).to be > 0

        first_event = award_events.first
        expect(first_event['awardEventStatus']).to eq('Authorized')
        expect(first_event['awardEventType']).to eq('S')

        expect(first_event['awardLineList']).to have_key('awardLines')
        award_lines = first_event['awardLineList']['awardLines']
        expect(award_lines).to be_an(Array)
        expect(award_lines.length).to be > 0

        first_line = award_lines.first
        expect(first_line['awardLineType']).to eq('IP')
        expect(first_line['grossAmount']).to eq('462.00')
        expect(first_line['netAmount']).to eq('462.00')
      end
    end
  end
end
