# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class ClaimsOverview
        def parse(entry)
          parsed_entry = if entry['list_data']
                           {
                             id: entry['evss_id'].to_s,
                             type: 'claim',
                             subtype: entry['list_data']['status_type'],
                             completed: entry['list_data']['status'] == 'COMPLETE',
                             date_filed: Date.strptime(entry['list_data']['date'], '%m/%d/%Y').iso8601,
                             updated_at: entry['updated_at'].to_time.iso8601
                           }
                         else
                           subtype = entry['type']
                           filed_index = subtype == 'legacyAppeal' ? 1 : 0
                           {
                             id: entry['id'],
                             type: 'appeal',
                             subtype: subtype,
                             completed: !entry['attributes']['active'],
                             date_filed: entry['attributes']['events'][filed_index]['date'],
                             updated_at: entry['attributes']['updated'].to_time.iso8601
                           }
                         end
          Mobile::V0::ClaimOverview.new(parsed_entry)
        end
      end
    end
  end
end
