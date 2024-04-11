# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_proc_service_v2'

describe ClaimsApi::VnpProcServiceV2 do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_proc_create' do
    it 'responds with a vnp_proc_id' do
      VCR.use_cassette('claims_api/bgs/vnp_proc_service_v2/vnp_proc_create') do
        result = subject.vnp_proc_create
        expect(result[:vnp_proc_id]).to eq '29637'
      end
    end
  end
end
