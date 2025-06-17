# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/phr_mgr/client'

describe PHRMgr::Client do
  context 'using API Gateway endpoints' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(true)
    end

    let(:icn) { '1000000000V000000' }
    let(:client) { PHRMgr::Client.new(icn) }

    it 'checks PHR refresh status', :vcr do
      VCR.use_cassette 'phr_mgr_client/apigw_check_phr_refresh_status' do
        response = client.get_phrmgr_status
        expect(response).to be_a(Hash)
      end
    end
  end

  context 'using legacy endpoints' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
    end

    describe 'PHR operations', :vcr do
      context 'when ICN is valid' do
        let(:icn) { '1000000000V000000' }
        let(:client) { PHRMgr::Client.new(icn) }

        it 'performs a PHR refresh', :vcr do
          VCR.use_cassette 'phr_mgr_client/perform_a_phr_refresh' do
            response = client.post_phrmgr_refresh
            expect(response).to equal(200)
          end
        end

        it 'checks PHR refresh status', :vcr do
          VCR.use_cassette 'phr_mgr_client/check_phr_refresh_status' do
            response = client.get_phrmgr_status
            expect(response).to be_a(Hash)
          end
        end
      end

      context 'when ICN is not properly formatted' do
        let(:icn) { '12345' }
        let(:client) { PHRMgr::Client.new(icn) }

        it 'raises an error', :vcr do
          VCR.use_cassette 'phr_mgr_client/perform_a_phr_refresh_with_bad_icn' do
            expect do
              client.post_phrmgr_refresh
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end

      context 'when ICN is blank' do
        let(:icn) { nil }
        let(:client) { PHRMgr::Client.new(icn) }

        it 'raises an error', :vcr do
          expect do
            client.post_phrmgr_refresh
          end.to raise_error(Common::Exceptions::ParameterMissing)
        end
      end
    end

    describe '#get_military_service' do
      let(:icn) { '1000000000V000000' }
      let(:client) { PHRMgr::Client.new(icn) }

      it "retrieves the user's military service" do
        VCR.use_cassette 'phr_mgr_client/get_military_service' do
          military_service = client.get_military_service('1234567890')

          expect(military_service).to be_a(String)
          expect(military_service).to include('Military Service Information')
        end
      end
    end
  end
end
