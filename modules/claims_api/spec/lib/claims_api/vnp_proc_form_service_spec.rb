# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_proc_form_service'

describe ClaimsApi::VnpProcFormService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe 'vnp_proc_form_service' do
    let(:options) { {} }

    it 'responds with a vnc_proc_id' do
      # options[:vnp_proc_id] = '3830252' # '3854437''3830249' #
      #   options[:vnp_ptcpnt_id] = nil
      #   options[:jrn_dt] = nil
      #   options[:jrn_obj_id] = nil
      #   options[:jrn_status_type_cd] = nil
      #   options[:jrn_user_id] = nil
      VCR.use_cassette('bgs/vnp_proc_service_v2/vnp_proc_form_service') do
        response = subject.vnp_proc_form_create(options)
        expect(response[:vnp_proc_id]).to eq '29637'
      end
    end
  end
end
