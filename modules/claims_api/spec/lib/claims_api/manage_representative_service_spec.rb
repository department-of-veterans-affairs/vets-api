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
end
