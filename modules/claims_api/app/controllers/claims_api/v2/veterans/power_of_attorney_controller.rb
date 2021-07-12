# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorneyController < ClaimsApi::V2::ApplicationController
        def show
          raise ::Common::Exceptions::Forbidden unless user_is_target_veteran? || user_is_representative?

          poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa.try(:code)
          head(:no_content) && return if poa_code.blank?

          render json: {
            code: poa_code,
            name: representative[:name],
            type: representative[:type],
            phone: {
              number: representative[:phone_number]
            }
          }
        end

        private

        def representative(poa_code)
          return @representative if @representative.present?

          organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
          if organization.present?
            @representative = {
              name: organization.name,
              phone_number: organization.phone,
              type: 'organization'
            }
            return @representative
          end

          individuals = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code)
          raise 'Ambiguous representative results' if individuals.count > 1

          individual = individuals.first
          @representative = {
            name: "#{individual.first_name} #{individual.last_name}",
            phone_number: individual.phone,
            type: 'individual'
          }
        end
      end
    end
  end
end
