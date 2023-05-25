# frozen_string_literal: true

require_relative 'claims_overview'

module Mobile
  module V0
    module Adapters
      class LighthouseClaimsOverview < ClaimsOverview
        def parse(list)
          list
            .map { |entry| entry['type'] == 'claim' ? parse_claim(entry) : parse_appeal(entry) }
            .sort_by { |entry| [entry[:updated_at] ? 1 : 0, entry[:updated_at]] }.reverse!
        end

        private

        def parse_claim(entry)
          attributes = entry['attributes']
          Mobile::V0::ClaimOverview.new(
            {
              id: entry['id'],
              type: 'claim',
              subtype: attributes['claimType'],
              completed: attributes['status'] == 'COMPLETE',
              date_filed: date(attributes['claimDate']),
              updated_at: date(attributes['claimPhaseDates']['phaseChangeDate']),
              display_title: attributes['claimType'],
              decision_letter_sent: attributes['decisionLetterSent']
            }
          )
        end

        def date(attribute)
          return nil unless attribute

          Date.strptime(attribute, '%Y-%m-%d').iso8601
        end
      end
    end
  end
end
