# frozen_string_literal: true

require 'fast_jsonapi'

module Mobile
  module V0
    class AppealOverviewSerializer
      include FastJsonapi::ObjectSerializer
      set_id :id do |appeal|
        appeal['id']
      end
      set_type :appeal
      attribute :subtype do |appeal|
        appeal['type']
      end
      attribute :completed do |appeal|
        !appeal['attributes']['active']
      end
      attribute :date_filed do |appeal|
        appeal['attributes']['events'][1]['date']
      end
      attribute :updated_at do |appeal|
        appeal['attributes']['updated'].to_time.iso8601
      end
    end
  end
end

