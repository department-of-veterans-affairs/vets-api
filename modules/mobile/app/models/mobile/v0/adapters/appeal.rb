# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Appeal
        def parse(appeal)
          Mobile::V0::Appeals::Appeal.new(
            id: appeal[:id],
            appealIds: appeal[:appealIds],
            active: appeal[:active],
            alerts: appeal[:alerts],
            aod: appeal[:aod],
            aoj: appeal[:aoj],
            description: appeal[:description],
            docket: appeal[:docket],
            events: appeal[:events].map(&:deep_symbolize_keys),
            evidence: appeal[:evidence],
            incompleteHistory: appeal[:incompleteHistory],
            issues: appeal[:issues].map(&:deep_symbolize_keys),
            location: appeal[:location],
            programArea: appeal[:programArea],
            status: appeal[:status].deep_symbolize_keys,
            type: appeal[:type],
            updated: appeal[:updated]
          )
        end
      end
    end
  end
end
