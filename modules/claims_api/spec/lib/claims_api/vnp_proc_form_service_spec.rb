# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_proc_form_service'

describe ClaimsApi::VnpProcFormService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_proc_form_create' do
    let(:options) { {} }

    it 'responds with a vnp_proc_id' do
      options[:vnp_proc_id] = '3831394'
      options[:vnp_ptcpnt_id] = nil
      options[:jrn_dt] = nil
      options[:jrn_obj_id] = 'VAgovAPI'
      options[:jrn_status_type_cd] = 'U'
      options[:jrn_user_id] = 'VAgovAPI'
      VCR.use_cassette('claims_api/bgs/vnp_proc_form_service/vnp_proc_form_create') do
        response = subject.vnp_proc_form_create(options)
        expect(response[:comp_id][:vnp_proc_id]).to eq '3831394'
      end
    end
  end
end
