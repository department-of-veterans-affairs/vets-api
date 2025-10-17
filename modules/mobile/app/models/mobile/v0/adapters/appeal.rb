# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class Appeal
        APPEAL_TYPE_DISPLAY_NAMES = {
          'higherLevelReview' => 'Higher-Level Review',
          'supplementalClaim' => 'Supplemental Claim'
        }.freeze

        def parse(appeal)
          Mobile::V0::Appeal.new(
            id: appeal[:id],
            appealIds: appeal[:appealIds],
            active: appeal[:active],
            alerts: Array.wrap(appeal[:alerts]),
            aod: appeal[:aod],
            aoj: appeal[:aoj],
            description: appeal[:description],
            docket: appeal[:docket],
            events: appeal[:events].map(&:deep_symbolize_keys),
            evidence: appeal[:evidence],
            incompleteHistory: appeal[:incompleteHistory],
            issues: update_null_issue_descriptions(appeal[:issues].map(&:deep_symbolize_keys), appeal[:type]),
            location: appeal[:location],
            programArea: appeal[:programArea],
            status: status(appeal[:status].deep_symbolize_keys),
            type: appeal[:type],
            updated: appeal[:updated]
          )
        end

        private

        # Prod has a common issue with this type having a typo
        def status(status)
          status[:type] = 'sc_received' if status[:type] == 'sc_recieved'
          status
        end

        # Updates null issue descriptions with a default string
        def update_null_issue_descriptions(issues, appeal_type)
          issues.map do |issue|
            if issue[:description].blank?
              issue[:description] = "We're unable to show this issue on #{format_appeal_type(appeal_type)}"
            end
            issue
          end
        end

        def format_appeal_type(appeal_type)
          if APPEAL_TYPE_DISPLAY_NAMES.key?(appeal_type)
            "your #{APPEAL_TYPE_DISPLAY_NAMES[appeal_type]}"
          else
            'appeal'
          end
        end
      end
    end
  end
end
