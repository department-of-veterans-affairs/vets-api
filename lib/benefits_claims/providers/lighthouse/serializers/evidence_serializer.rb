# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module EvidenceSerializer
          def self.serialize(evidence_list)
            evidence_list.map do |ev|
              {
                'date' => ev.date,
                'description' => ev.description,
                'type' => ev.type
              }
            end
          end
        end
      end
    end
  end
end
