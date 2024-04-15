# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/sis_session_helper'

RSpec.describe Mobile::V0::AwardsController, type: :request do
  before do
    sis_user(participant_id: 600_061_742)
  end

  describe 'GET /mobile/v0/awards' do
    it 'responds to GET #index' do
      VCR.use_cassette('bgs/awards_service/get_awards') do
        VCR.use_cassette('bid/awards/get_awards_pension') do
          get '/mobile/v0/awards', headers: sis_headers
        end
      end

      expect(response).to be_successful
      expect(response.parsed_body['data']['attributes']).to eq(
        { 'id' => sis_user.uuid,
          'aportnRecipId' => '2810777',
          'awardAmt' => '541.83',
          'awardCmpsitId' => '10976',
          'awardCurntStatusCd' => 'A',
          'awardEventId' => '13724',
          'awardLineReportId' => '37898',
          'awardLineTypeCd' => 'C',
          'awardStnNbr' => '317',
          'awardTypeCd' => 'CPL',
          'combndDegreePct' => '30',
          'depHlplsThisNbr' => '0',
          'depHlplsTotalNbr' => '0',
          'depSchoolThisNbr' => '0',
          'depSchoolTotalNbr' => '0',
          'depThisNbr' => '12',
          'depTotalNbr' => '12',
          'efctvDt' => '2020-08-01T00:00:00.000-05:00',
          'entlmtTypeCd' => '41',
          'fileNbr' => '796121200',
          'futureEfctvDt' => '2021-07-15T00:00:00.000-05:00',
          'grossAdjsmtAmt' => '0.0',
          'grossAmt' => '541.83',
          'ivapAmt' => '0.0',
          'jrnDt' => '2020-08-03T18:15:02.000-05:00',
          'jrnLctnId' => '281',
          'jrnObjId' => 'AWARD COMPOSITE',
          'jrnStatusTypeCd' => 'I',
          'jrnUserId' => 'BATCH',
          'netAmt' => '541.83',
          'payeeTypeCd' => '00',
          'priorEfctvDt' => '2020-07-01T00:00:00.000-05:00',
          'ptcpntBeneId' => '2810777',
          'ptcpntVetId' => '2810777',
          'reasonOneTxt' => '21',
          'spouseTxt' => 'Spouse' }
      )
    end

    context 'when upstream service returns error' do
      it 'returns error' do
        allow_any_instance_of(BGS::AwardsService).to receive(:get_awards).and_return(false)
        get '/mobile/v0/awards', headers: sis_headers

        error = { 'errors' => [{ 'title' => 'Bad Gateway',
                                 'detail' => 'Received an an invalid response from the upstream server',
                                 'code' => 'MOBL_502_upstream_error', 'status' => '502' }] }
        expect(response).to have_http_status(:bad_gateway)
        expect(response.parsed_body).to eq(error)
      end
    end
  end
end
