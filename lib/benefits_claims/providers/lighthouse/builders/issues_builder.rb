# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module IssuesBuilder
          def self.build(issues_data)
            return nil if issues_data.nil?
            return [] if issues_data.empty?

            issues_data.map do |issue_data|
              BenefitsClaims::Responses::Issue.new(
                active: issue_data['active'],
                description: issue_data['description'],
                diagnostic_code: issue_data['diagnosticCode'],
                last_action: issue_data['lastAction'],
                date: issue_data['date']
              )
            end
          end
        end
      end
    end
  end
end
