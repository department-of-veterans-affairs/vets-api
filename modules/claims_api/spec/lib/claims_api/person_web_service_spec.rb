# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/person_web_service'

describe ClaimsApi::PersonWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe '#find_dependents_by_ptcpnt_id' do
    it 'responds as expected' do
      VCR.use_cassette('claims_api/bgs/claimant_web_service/find_dependents_by_ptcpnt_id') do
        # rubocop:disable Style/NumericLiterals
        result = subject.find_dependents_by_ptcpnt_id(600052699)
        # rubocop:enable Style/NumericLiterals
        expect(result).to be_a Hash
        expect(result[:dependent][:first_nm]).to eq 'MARGIE'
      end
    end
  end
end
