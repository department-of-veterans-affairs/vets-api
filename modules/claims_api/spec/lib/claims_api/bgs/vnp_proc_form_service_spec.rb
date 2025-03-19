# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_proc_form_service'

describe ClaimsApi::VnpProcFormService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_proc_form_create' do
    let(:options) { {} }

    it 'responds with a vnp_proc_id' do
      options[:vnp_proc_id] = '3860232'
      options[:vnp_ptcpnt_id] = nil
      VCR.use_cassette('claims_api/bgs/vnp_proc_form_service/vnp_proc_form_create') do
        response = subject.vnp_proc_form_create(options)
        expect(response[:comp_id][:vnp_proc_id]).to eq '3860232'
      end
    end

    it 'responds appropriately with invalid options' do
      options[:vnp_proc_id] = 'not-an-id'
      options[:vnp_ptcpnt_id] = nil
      VCR.use_cassette('claims_api/bgs/vnp_proc_form_service/invalid_vnp_proc_form_create') do
        expect do
          subject.vnp_proc_form_create(options)
        end.to raise_error(Common::Exceptions::UnprocessableEntity)
      end
    end
  end
end
