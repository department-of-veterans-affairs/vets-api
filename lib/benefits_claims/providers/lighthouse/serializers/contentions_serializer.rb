# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module ContentionsSerializer
          def self.serialize(contentions)
            contentions.map do |contention|
              {
                'name' => contention.name
              }
            end
          end
        end
      end
    end
  end
end
