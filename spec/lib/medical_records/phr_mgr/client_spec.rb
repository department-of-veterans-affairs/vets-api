# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/phr_mgr/client'

describe PHRMgr::Client do
  context 'using API Gateway endpoints' do
    let(:icn) { '1000000000V000000' }
    let(:client) { PHRMgr::Client.new(icn) }

    it 'checks PHR refresh status', :vcr do
      VCR.use_cassette 'phr_mgr_client/apigw_check_phr_refresh_status' do
        response = client.get_phrmgr_status
        expect(response).to be_a(Hash)
      end
    end
  end
end
