# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Serializers
        module EventsSerializer
          def self.serialize(events)
            events.map do |event|
              {
                'date' => event.date,
                'type' => event.type
              }
            end
          end
        end
      end
    end
  end
end
