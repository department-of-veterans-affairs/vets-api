# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/phr_mgr/client'

describe PHRMgr::Client do
  let(:client) { PHRMgr::Client.new }

  describe 'PHR operations', :vcr do
    context 'when ICN is valid' do
      let(:icn) { '1000000000V000000' }

      it 'performs a PHR refresh', :vcr do
        VCR.use_cassette 'phr_mgr_client/perform_a_phr_refresh' do
          response = client.post_phrmgr_refresh(icn)
          expect(response).to equal(200)
        end
      end

      it 'checks PHR refresh status', :vcr do
        VCR.use_cassette 'phr_mgr_client/check_phr_refresh_status' do
          response = client.get_phrmgr_status(icn)
          expect(response).to be_a(Hash)
        end
      end
    end

    context 'when ICN is not properly formatted' do
      let(:icn) { '12345' }

      it 'performs a PHR refresh', :vcr do
        VCR.use_cassette 'phr_mgr_client/perform_a_phr_refresh_with_bad_icn' do
          expect do
            # Raises #<PHRMgr::ServiceException "BackendServiceException:
            #        {:status=>400, :detail=>\"Invalid ICN\", :code=>\"VA900\", :source=>nil}">
            client.post_phrmgr_refresh(icn)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end
end
