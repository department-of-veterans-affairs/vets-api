# frozen_string_literal: true

require 'rails_helper'

class FakeController
  include ClaimsApi::V2::ClaimsRequests::TrackedItemsAssistance
end

describe FakeController do
  context 'when the claims controller calls the TrackedItemsAssistance module' do
    let(:claim_date) { Date.parse('2024-08-22 07:36:25 -0600') }
    let(:status) { 'Complete' }
    let(:wwsnfy) do
      [{ date_open: '2021-05-05', dvlpmt_item_id: '293439', items: 'You may be able ...',
         suspense_dt: '2021-06-04' }]
    end
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

    it '#date_present' do
      result = subject.date_present(claim_date)
      expect(result).to eq('2024-08-22')
    end

    it '#format_bgs_date' do
      result = subject.format_bgs_date(claim_date)
      expect(result).to eq('2024-08-22')
    end

    it '#accepted?' do
      result = subject.accepted?(status)
      expect(result).to be(true)
    end

    it '#overdue?' do
      result = subject.overdue?(tracked_item, wwsnfy)
      expect(result).to be(true)
    end

    it '#tracked_item_req_date' do
      result = subject.tracked_item_req_date(tracked_item, item)
      expect(result).to eq('2021-05-05')
    end

    it '#uploads_allowed?' do
      result = subject.uploads_allowed?(status)
      expect(result).to be(false)
    end
  end
end
