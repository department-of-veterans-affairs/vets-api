# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_proc_service_v2'

describe ClaimsApi::VnpProcServiceV2 do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_proc_create' do
    it 'responds with a vnp_proc_id' do
      VCR.use_cassette('claims_api/bgs/vnp_proc_service_v2/vnp_proc_create') do
        result = subject.vnp_proc_create
        expect(result[:vnp_proc_id]).to eq '3860232'
      end
    end

    context 'when BGS is not available' do
      before do
        allow_any_instance_of(ClaimsApi::LocalBGS)
          .to receive(:make_request).and_raise(Common::Exceptions::BadGateway)
      end

      it 'raises BadGateway error' do
        expect do
          subject.vnp_proc_create
        end.to raise_error(Common::Exceptions::BadGateway)
      end
    end
  end
end
