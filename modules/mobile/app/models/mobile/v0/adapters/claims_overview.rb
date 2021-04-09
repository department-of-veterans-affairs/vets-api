# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverview
        def parse(list)
          list
            .map { |entry| entry['list_data'] ? parse_claim(entry) : parse_appeal(entry) }
            .sort_by(&:updated_at).reverse!
        end

        private

        def parse_claim(entry)
          Mobile::V0::ClaimOverview.new(
            {
              id: entry['evss_id'].to_s,
              type: 'claim',
              subtype: entry['list_data']['status_type'],
              completed: entry['list_data']['status'] == 'COMPLETE', # TODO: ADJ what's the business logic  here?
              date_filed: Date.strptime(entry['list_data']['date'], '%m/%d/%Y').iso8601,
              updated_at: Date.strptime(
                entry['list_data']['claim_phase_dates']['phase_change_date'], '%m/%d/%Y'
              ).to_time.iso8601
            }
          )
        end

        def parse_appeal(entry)
          subtype = entry['type']
          filed_index = subtype == 'legacyAppeal' ? 1 : 0
          Mobile::V0::ClaimOverview.new(
            {
              id: entry['id'],
              type: 'appeal',
              subtype: subtype,
              completed: !entry['attributes']['active'],
              date_filed: entry['attributes']['events'][filed_index]['date'],
              updated_at: DateTime.parse(entry['attributes']['events'].last['date']).iso8601
            }
          )
        end
      end
    end
  end
end
