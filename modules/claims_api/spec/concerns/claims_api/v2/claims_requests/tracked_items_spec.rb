# frozen_string_literal: true

require 'rails_helper'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::TrackedItems

  def local_bgs_service
    @local_bgs_service ||= ClaimsApi::LocalBGS.new(
      external_uid: target_veteran.participant_id,
      external_key: target_veteran.participant_id
    )
  end

  def target_veteran
    OpenStruct.new(
      icn: '1013062086V794840',
      first_name: 'abraham',
      last_name: 'lincoln',
      loa: { current: 3, highest: 3 },
      ssn: '796111863',
      edipi: '8040545646',
      participant_id: '600061742',
      mpi: OpenStruct.new(
        icn: '1013062086V794840',
        profile: OpenStruct.new(ssn: '796111863')
      )
    )
  end
end

describe FakeController do
  context 'when the claims controller calls the tracked_items module' do
    let(:claim_id) { '600118544' }

    it 'makes a successful call to BGS' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        result = subject.find_tracked_items!(claim_id)
        expect(result[0][:name]).to eq('DevelopmentItem')
        expect(result[0][:claim_id]).to eq('600118544')
      end
    end

    it 'is able to get a tracked_item' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        @tracked_items = subject.find_tracked_items!(claim_id)
        allow_any_instance_of(ClaimsApi::V2::ClaimsRequests::TrackedItems)
          .to receive(:find_tracked_items!).with(claim_id).and_return(@tracked_items)
        result = subject.find_tracked_item(@tracked_items[0][:dvlpmt_item_id])
        expect(result[:name]).to eq('DevelopmentItem')
        expect(result[:claim_id]).to eq('600118544')
      end
    end
  end
end
