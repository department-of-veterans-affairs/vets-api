# frozen_string_literal: true

require_relative 'claims_overview'

module Mobile
  module V0
    module Adapters
      class LighthouseClaimsOverview < ClaimsOverview
        def parse(list)
          list
            .map { |entry| entry['type'] == 'claim' ? parse_claim(entry) : parse_appeal(entry) }
            .sort_by(&:updated_at).reverse!
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
              date_filed: Date.strptime(attributes['claimDate'], '%Y-%m-%d').iso8601,
              updated_at: Date.strptime(
                attributes['claimPhaseDates']['phaseChangeDate'], '%Y-%m-%d'
              ).iso8601,
              display_title: attributes['claimType'],
              decision_letter_sent: attributes['decisionLetterSent']
            }
          )
        end
      end
    end
  end
end
