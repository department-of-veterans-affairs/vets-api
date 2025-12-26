# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module EventsBuilder
          def self.build(events_data)
            return nil if events_data.nil?
            return [] if events_data.empty?

            events_data.map do |event_data|
              BenefitsClaims::Responses::Event.new(
                date: event_data['date'],
                type: event_data['type']
              )
            end
          end
        end
      end
    end
  end
end
