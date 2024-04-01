# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_ptcpnt_service'
require 'bgs_service/vnp_proc_service_v2'
require 'bgs_service/vnp_person_create_v2'

describe ClaimsApi::VnpPersonCreateV2 do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  # get a proc_id from vnp_proc_create
  # get a ptcpnt_id from vnp_ptcpnt_create (using the proc_id from the previous step)
  let(:vnp_proc_id) { '3854545' }
  let(:vnp_ptcpnt_id) { '182008' }

  describe 'vnp_person_create_v2' do
    it 'validates data' do
      data = { asdf: 'qwerty' }
      e = an_instance_of(ArgumentError).and having_attributes(
        message: 'Missing required keys: vnpProcId, vnpPtcpntId, firstNm, lastNm'
      )
      expect { subject.vnp_person_create(data) }.to raise_error(e)
    end

    it 'creates a new person' do
      data = {
        vnp_proc_id:,
        vnp_ptcpnt_id:,
        first_nm: 'Tamara',
        last_nm: 'Ellis'
      }
      VCR.use_cassette('bgs/vnp_proc_service_v2/vnp_person_create') do
        result = subject.vnp_person_create(data)
        expect((data.to_a & result.to_a).to_h).to eq data
      end
    end
  end
end
