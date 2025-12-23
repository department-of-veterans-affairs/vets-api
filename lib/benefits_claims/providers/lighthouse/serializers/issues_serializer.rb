# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module IssuesSerializer
          def self.serialize(issues)
            issues.map do |issue|
              {
                'active' => issue.active,
                'description' => issue.description,
                'diagnosticCode' => issue.diagnostic_code,
                'lastAction' => issue.last_action,
                'date' => issue.date
              }
            end
          end
        end
      end
    end
  end
end
