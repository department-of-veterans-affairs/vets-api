# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/standard_data_web_service'

describe ClaimsApi::StandardDataWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe '#find_poas' do
    it 'responds as expected' do
      VCR.use_cassette('claims_api/bgs/standard_data_web_service/find_poas') do
        result = subject.find_poas
        expect(result).to be_a Array
        expect(result.first).to be_a Hash
        expect(result.first[:legacy_poa_cd]).to eq '002'
      end
    end
  end
end
