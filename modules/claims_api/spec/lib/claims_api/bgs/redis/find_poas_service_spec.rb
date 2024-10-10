# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/redis/find_poas_service'

describe ClaimsApi::FindPOAsService do
  describe '#response' do
    context 'when the response is not cached' do
      it 'calls bgs and returns the response' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          service = described_class.new
          allow(service).to receive(:standard_data_web_service).and_call_original
          response = service.response

          expect(service).to have_received(:standard_data_web_service)
          expect(response).to be_an_instance_of(Array)
          expect(response.first).to include(:legacy_poa_cd, :ptcpnt_id)
        end
      end
    end

    context 'when the response is cached' do
      it 'does not call bgs and returns the cached response' do
        VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
          # Call BGS and cache the response
          first_service = described_class.new
          first_service.response

          # The second service should not call BGS
          second_service = described_class.new
          allow(second_service).to receive(:standard_data_web_service).and_call_original
          second_service.response

          expect(second_service).not_to have_received(:standard_data_web_service)
          expect(second_service.response).to be_an_instance_of(Array)
          expect(second_service.response.first).to include(:legacy_poa_cd, :ptcpnt_id)
        end
      end
    end
  end
end
