# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/tracked_item_service'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::TrackedItems
  include ClaimsApi::V2::ClaimsRequests::TrackedItemsAssistance

  def tracked_item_service
    @tracked_item_service ||= ClaimsApi::TrackedItemService.new(
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
    let(:bgs_claim) do
      { benefit_claim_details_dto: { benefit_claim_id: '111111111',
                                     phase_chngd_dt: '2024-08-19 06:58:18 -0600',
                                     phase_type: 'Pending Decision Approval',
                                     ptcpnt_clmant_id: 10_969_622_233_703_603, ptcpnt_vet_id: '600061742',
                                     phase_type_change_ind: '76', claim_status_type: 'Compensation',
                                     bnft_claim_lc_status: [{ max_est_claim_complete_dt: '2024-08-19 06:55:17 -0600',
                                                              min_est_claim_complete_dt: '2024-08-18 06:07:17 -0600',
                                                              phase_chngd_dt: '2024-08-18 10:58:59 -0600',
                                                              phase_type: 'Claim Received',
                                                              phase_type_change_ind: 'N' }] } }
    end
    let(:status) { 'Complete' }
    let(:tracked_item) do
      { jrn_dt: '2021-05-05T09:49:04-05:00', name: 'DevelopmentItem', claim_id: '600236068',
        create_dt: '2021-05-05T09:49:04-05:00', create_ptcpnt_id: '600052904', create_stn_num: '317',
        docid: '815705', dvlpmt_item_id: '293439', dvlpmt_tc: 'CLMNTRQST',
        req_dt: '2021-05-05T00:00:00-05:00', short_nm: 'STRs not available - substitute documents needed',
        std_devactn_id: '101', suspns_dt: '2021-06-04T00:00:00-05:00' }
    end
    let(:item) do
      { date_open: '2021-05-05', dvlpmt_item_id: '293439', items: 'You may be able to...',
        suspense_dt: '2021-06-04' }
    end

    it 'makes a successful call to BGS' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        result = subject.find_tracked_items!(claim_id)
        expect(result[0][:name]).to eq('DevelopmentItem')
        expect(result[0][:claim_id]).to eq('600118544')
      end
    end

    it '#build_tracked_item' do
      result = subject.build_tracked_item(tracked_item, status, item, wwsnfy: false)
      expected = { closed_date: nil, description: 'You may be able to...',
                   display_name: 'STRs not available - substitute documents needed',
                   overdue: false, received_date: nil, requested_date: '2021-05-05', status: 'Complete',
                   suspense_date: '2021-06-04', id: 293_439, uploads_allowed: false }
      expect(result).to eq(expected)
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

    it '#map_bgs_tracked_items' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        result = subject.map_bgs_tracked_items(bgs_claim)
        expect(result).to eq([])
      end
    end

    it '#build_wwsnfy_items' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        subject.map_bgs_tracked_items(bgs_claim)
        result = subject.build_wwsnfy_items
        expect(result).to eq([])
      end
    end

    it '#build_wwd_items' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        subject.map_bgs_tracked_items(bgs_claim)
        result = subject.build_wwd_items
        expect(result).to eq([])
      end
    end

    it '#build_wwr_items' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        subject.map_bgs_tracked_items(bgs_claim)
        result = subject.build_wwr_items
        expect(result).to eq([])
      end
    end

    it '#build_no_longer_needed_items' do
      VCR.use_cassette('claims_api/bgs/tracked_items/find_tracked_items') do
        result = subject.build_no_longer_needed_items
        expect(result).to eq([])
      end
    end
  end
end
