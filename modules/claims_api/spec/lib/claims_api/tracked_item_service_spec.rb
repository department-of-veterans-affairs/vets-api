# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/tracked_item_service'

describe ClaimsApi::TrackedItemService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:claim_id) { '600118544' }

  describe '#find_tracked_items(id)' do
    it 'responds as expected with a valid claim id' do
      VCR.use_cassette('claims_api/bgs/tracked_item_service/find_tracked_items') do
        result = subject.find_tracked_items(claim_id)
        expect(result).to be_a Hash
        expect(result[:dvlpmt_items]).to be_a Array
        expect(result[:dvlpmt_items].first[:name]).to eq('DevelopmentItem')
        expect(result[:dvlpmt_items].first[:dvlpmt_item_id]).to eq('325525')
      end
    end

    it 'responds as expected with a invalid claim id' do
      VCR.use_cassette('claims_api/bgs/tracked_item_service/invalid_find_tracked_items') do
        subject.find_tracked_items('not_a_claim_id')
      rescue => e
        expect(e).to be_a(Common::Exceptions::UnprocessableEntity)
        expect(e.message).to be('Unprocessable Entity')
      end
    end
  end
end
