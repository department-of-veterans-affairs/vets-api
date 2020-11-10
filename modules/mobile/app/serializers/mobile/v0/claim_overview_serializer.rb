# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class ClaimOverviewSerializer
      include FastJsonapi::ObjectSerializer
      set_id :id do |claim|
        claim[:evss_id]
      end
      set_type :claim
      attribute :subtype do |claim|
        claim[:list_data]['status_type']
      end
      attribute :completed do |claim|
        claim[:list_data]['claim_status'] != 'PEND'
      end
      attribute :date_filed do |claim|
        Date.strptime(claim[:list_data]['date'], '%m/%d/%Y').strftime('%Y-%m-%d')
      end
      attribute :updated_at do |claim|
        claim[:updated_at].to_time.iso8601
      end
    end
  end
end
