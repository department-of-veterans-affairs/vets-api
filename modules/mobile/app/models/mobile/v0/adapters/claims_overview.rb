# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverview
        def parse(entry)
          if entry['list_data']
            {
              id: entry['evss_id'].to_s,
              type: 'claim',
              subtype: entry['list_data']['status_type'],
              completed: entry['list_data']['claim_status'] != 'PEND',
              date_filed: Date.strptime(entry['list_data']['date'], '%m/%d/%Y').iso8601,
              updated_at: entry['updated_at'].to_time.iso8601
            }
          else
            {
              id: entry['id'],
              type: 'appeal',
              subtype: entry['type'],
              completed: !entry['attributes']['active'],
              date_filed: entry['attributes']['events'][1]['date'],
              updated_at: entry['attributes']['updated'].to_time.iso8601
            }
          end
        end
      end
    end
  end
end
