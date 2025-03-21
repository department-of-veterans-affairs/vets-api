# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/vnp_person_service'
require Rails.root.join('modules', 'claims_api', 'spec', 'support', 'bgs_client_spec_helpers.rb')

metadata = {
  bgs: {
    service: 'vnp_person_service',
    action: 'vnp_person_create'
  }
}

describe ClaimsApi::VnpPersonService, metadata do
  describe '#vnp_person_create' do
    subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

    # get a proc_id from vnp_proc_create
    # get a ptcpnt_id from vnp_ptcpnt_create (using the proc_id from the previous step)
    let(:vnp_proc_id) { '3860232' }
    let(:vnp_ptcpnt_id) { '189015' }
    let(:expected_response) do
      { vnp_proc_id:, vnp_ptcpnt_id:,
        first_nm: 'Tamara', last_nm: 'Ellis' }
    end

    it 'validates data' do
      data = { asdf: 'qwerty' }
      e = an_instance_of(ArgumentError).and having_attributes(
        message: 'Missing required keys: vnp_proc_id, vnp_ptcpnt_id, first_nm, last_nm'
      )
      expect { subject.vnp_person_create(data) }.to raise_error(e)
    end

    describe 'valid data' do
      it 'creates a new person from data', run_at: '2024-04-01T18:48:27Z' do
        data = {
          vnp_proc_id:,
          vnp_ptcpnt_id:,
          first_nm: 'Tamara',
          last_nm: 'Ellis'
        }

        use_bgs_cassette('happy_path') do
          result = subject.vnp_person_create(data)
          expect((expected_response.to_a & result.to_a).to_h).to eq expected_response
        end
      end
    end

    describe 'invalid procId' do
      it 'raises an error', run_at: '2024-04-01T18:48:27Z' do
        data = {
          vnp_proc_id: '1234',
          vnp_ptcpnt_id:,
          first_nm: 'Tamara',
          last_nm: 'Ellis'
        }

        use_bgs_cassette('invalid_procId') do
          expect { subject.vnp_person_create(data) }.to raise_error(Common::Exceptions::ServiceError)
        end
      end
    end
  end
end
