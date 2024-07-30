# frozen_string_literal: true

require 'claims_api/v2/params_validation/veteran_identifier'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::ApplicationController
      def find
        validate_request!(ClaimsApi::V2::ParamsValidation::VeteranIdentifier)
        raise ::Common::Exceptions::ResourceNotFound if target_veteran&.mpi&.icn.blank?
        unless ccg_flow?(token:) || user_is_target_veteran? || user_is_representative?
          raise ::Common::Exceptions::Forbidden
        end

        render json: ClaimsApi::V2::Blueprints::VeteranIdentifierBlueprint.render(target_veteran), status: :created
      end

      protected

      def target_veteran
        @target_veteran ||= ClaimsApi::Veteran.new(
          uuid: params[:ssn],
          ssn: params[:ssn],
          first_name: params[:firstName],
          last_name: params[:lastName],
          va_profile: ClaimsApi::Veteran.build_profile(params[:birthdate]),
          loa: ccg_flow?(token:) ? { current: 3, highest: 3 } : @current_user.loa
        )
      end

      def user_is_target_veteran?
        return false unless @current_user.first_name.casecmp?(target_veteran.first_name)
        return false unless @current_user.last_name.casecmp?(target_veteran.last_name)
        return false unless @current_user.ssn == target_veteran.ssn
        return false unless Date.parse(@current_user.birth_date) == Date.parse(target_veteran.birth_date)

        true
      end

      private

      def ccg_flow?(token:)
        token.client_credentials_token?
      end
    end
  end
end
