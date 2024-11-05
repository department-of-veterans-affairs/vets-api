# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Pensions', type: :request do
  before do
    sis_user(participant_id: 600_061_742)
  end

  describe 'GET /mobile/v0/pensions' do
    it 'responds to GET #index' do
      VCR.use_cassette('bid/awards/get_awards_pension') do
        get '/mobile/v0/pensions', headers: sis_headers
      end

      expect(response).to be_successful
      expect(response.parsed_body['data']['attributes']).to eq(
        { 'isEligibleForPension' => true,
          'isInReceiptOfPension' => true,
          'netWorthLimit' => 129_094 }
      )
    end

    context 'when upstream service returns error' do
      it 'returns error' do
        allow_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_return(false)
        get '/mobile/v0/pensions', headers: sis_headers

        error = { 'errors' => [{ 'title' => 'Bad Gateway',
                                 'detail' => 'Received an an invalid response from the upstream server',
                                 'code' => 'MOBL_502_upstream_error', 'status' => '502' }] }
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body).to eq(error)
      end
    end
  end
end
