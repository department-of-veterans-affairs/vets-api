# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/standard_data_service'

describe ClaimsApi::StandardDataService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  describe '#get_contention_classification_type_code_list' do
    it 'responds as expected' do
      VCR.use_cassette(
        'claims_api/bgs/standard_data_service/get_contention_classification_type_code_list'
      ) do
        result = subject.get_contention_classification_type_code_list

        expect(result).to be_a Array
        expect(result.first).to be_a Hash
        expect(result.first[:name]).to eq('ContentionClassification')
        expect(result.first[:clsfcn_id]).to eq('10')
        expect(result.first[:clsfcn_txt]).to eq('abnormal heart')
      end
    end
  end
end
