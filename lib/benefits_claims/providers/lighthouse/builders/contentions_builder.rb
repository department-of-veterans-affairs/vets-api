# frozen_string_literal: true

module BenefitsClaims
  module Providers
    module Lighthouse
      module Builders
        module ContentionsBuilder
          def self.build(contentions_data)
            return nil if contentions_data.nil?
            return [] if contentions_data.empty?

            contentions_data.map do |contention_data|
              BenefitsClaims::Responses::Contention.new(
                name: contention_data['name']
              )
            end
          end
        end
      end
    end
  end
end
