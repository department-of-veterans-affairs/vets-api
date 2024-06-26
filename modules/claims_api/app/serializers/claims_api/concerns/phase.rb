# frozen_string_literal: true

module ClaimsApi
  module Concerns
    module Phase
      extend ActiveSupport::Concern

      PHASE_MAPPING = {
        'claim received' => 1,
        'under review' => 2,
        'gathering of evidence' => 3,
        'review of evidence' => 4,
        'preparation for decision' => 5,
        'pending decision approval' => 6,
        'preparation for notification' => 7,
        'complete' => 8
      }.freeze

      included do
        include JSONAPI::Serializer

        attribute :phase do |object|
          s = object_data(object).dig('claim_phase_dates', 'latest_phase_type')&.downcase
          phase = PHASE_MAPPING[s]
          phase
        end

        attribute :phase_change_date do |object|
          parse_date(object, 'claim_phase_dates', 'phase_change_date')
        end

        attribute :ever_phase_back do |object|
          object_data(object).dig('claim_phase_dates', 'ever_phase_back')
        end

        attribute :current_phase_back do |object|
          object_data(object).dig('claim_phase_dates', 'current_phase_back')
        end
      end

      class_methods do
        def parse_date(object, *keys, format: '%m/%d/%Y')
          date = object_data(object).dig(*keys)
          date ? Date.strptime(date, format) : nil
        end
      end
    end
  end
end
