# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module EvidenceBuilder
          def self.build(evidence_data)
            return nil if evidence_data.nil?
            return [] if evidence_data.empty?

            evidence_data.map do |ev_data|
              BenefitsClaims::Responses::Evidence.new(
                date: ev_data['date'],
                description: ev_data['description'],
                type: ev_data['type']
              )
            end
          end
        end
      end
    end
  end
end
