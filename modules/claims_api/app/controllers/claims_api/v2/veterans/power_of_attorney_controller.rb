# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

module ClaimsApi
  module V2
    module Veterans
      class PowerOfAttorneyController < ClaimsApi::V2::ApplicationController
        def show
          raise ::Common::Exceptions::Forbidden unless user_is_target_veteran? || user_is_representative?

          poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa_code
          head(:no_content) && return if poa_code.blank?

          render json: ClaimsApi::V2::Blueprints::PowerOfAttorneyBlueprint.render(
            representative(poa_code).merge({ code: poa_code })
          )
        end

        private

        def representative(poa_code)
          organization = ::Veteran::Service::Organization.find_by(poa: poa_code)
          if organization.present?
            return {
              name: organization.name,
              phone_number: organization.phone,
              type: 'organization'
            }
          end

          individuals = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code)
          raise 'Ambiguous representative results' if individuals.count > 1
          return {} if individuals.blank?

          individual = individuals.first
          {
            name: "#{individual.first_name} #{individual.last_name}",
            phone_number: individual.phone,
            type: 'individual'
          }
        end
      end
    end
  end
end
