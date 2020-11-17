# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class ClaimOverviewSerializer
      include FastJsonapi::ObjectSerializer
      set_id :id do |claim|
        claim['id']
      end
      set_type :claim
      attribute :subtype do |claim|
        claim['status_type']
      end
      attribute :completed do |claim|
        claim['claim_status'] != 'PEND'
      end
      attribute :date_filed do |claim|
        Date.strptime(claim['date'], '%m/%d/%Y').iso8601
      end
    end
  end
end
