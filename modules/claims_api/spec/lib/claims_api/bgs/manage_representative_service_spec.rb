# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/manage_representative_service'

describe ClaimsApi::ManageRepresentativeService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe '#read_poa_request' do
    let(:poa_codes) { %w[002 003 083] }

    it 'responds as expected with valid poa codes' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request') do
        result = subject.read_poa_request(poa_codes:)
        expect(result).to be_a Hash
        expect(result['poaRequestRespondReturnVOList']).to be_a Array
        expect(result['poaRequestRespondReturnVOList'].first['VSOUserFirstName']).to eq('vets-api')
      end
    end

    it 'responds as expected with invalid poa codes' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/invalid_read_poa_request') do
        subject.read_poa_request(poa_codes: [])
      rescue => e
        expect(e).to be_a(Common::Exceptions::ServiceError)
        expect(e.message).to eq('Unknown Service Error')
      end
    end
  end

  describe '#update_poa_request' do
    let(:proc_id) { '8675309' }
    let(:representative) do
      create(
        :representative,
        {
          poa_codes: ['A1Q'],
          first_name: 'abraham',
          last_name: 'lincoln'
        }
      )
    end

    it 'responds as expected with valid proc id' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_request_accepted') do
        result = subject.update_poa_request(proc_id:, representative:)

        expect(result).to be_a Hash
      end
    end

    it 'responds as expected with invalid proc id' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/invalid_update_poa_request') do
        subject.update_poa_request(proc_id: '')
      rescue => e
        expect(e).to be_a(Common::Exceptions::ServiceError)
        expect(e.message).to eq('Unknown Service Error')
      end
    end
  end

  describe '#read_poa_request_by_ptcpnt_id' do
    let(:ptcpnt_id) { '600061742' }

    it 'responds as expected with valid ptcpnt_id' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/read_poa_request_by_ptcpnt_id') do
        result = subject.read_poa_request_by_ptcpnt_id(ptcpnt_id:)

        expect(result['poaRequestRespondReturnVOList']).to be_a Hash
        expect(result['poaRequestRespondReturnVOList']['VSOUserEmail']).to eq('Beatrice.Stroud44@va.gov')
      end
    end

    it 'responds as expected with invalid ptcpnt_id' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/invalid_read_poa_request_by_ptcpnt_id') do
        subject.read_poa_request_by_ptcpnt_id(ptcpnt_id: '')
      rescue => e
        expect(e).to be_a(Common::Exceptions::ServiceError)
        expect(e.message).to eq('Unknown Service Error')
      end
    end
  end

  describe '#update_poa_relationship' do
    it 'formats the body correctly with valid parameters' do
      VCR.use_cassette('claims_api/bgs/manage_representative_service/update_poa_relationship') do
        pctpnt_id = '600095701'
        file_number = '796263749'
        ssn = '123456789'
        poa_code = '083'

        res = subject.update_poa_relationship(
          pctpnt_id:,
          file_number:,
          ssn:,
          poa_code:
        )

        expect(res['vetPtcpntId']).to eq(pctpnt_id)
        expect(res['vsoPOACode']).to eq(poa_code)
      end
    end
  end
end
