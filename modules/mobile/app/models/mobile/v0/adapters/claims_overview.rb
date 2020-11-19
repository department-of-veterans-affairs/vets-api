# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverview
        def parse(entry)
          {
              id: entry['evss_id'] ? entry['evss_id'].to_s : entry['id'],
              type: entry['list_data'] ? 'claim' : 'appeal',
              subtype: entry['list_data'] ? entry['list_data']['status_type'] : entry['type'],
              completed: entry['list_data'] ?
                             entry['list_data']['claim_status'] != 'PEND' : !entry['attributes']['active'],
              date_filed: entry['list_data'] ?
                              Date.strptime(entry['list_data']['date'], '%m/%d/%Y').iso8601 :
                              entry['attributes']['events'][1]['date'],
              updated_at: entry['updated_at'] ?
                              entry['updated_at'].to_time.iso8601 :
                              entry['attributes']['updated'].to_time.iso8601
          }
        end
      end
    end
  end
end