# frozen_string_literal: true

require 'claims_api/v2/params_validation/veteran_identifier'

module ClaimsApi
  module V2
    class VeteranIdentifierController < ClaimsApi::V2::ApplicationController
      def find
        validate_request!(ClaimsApi::V2::ParamsValidation::VeteranIdentifier)
        raise ::Common::Exceptions::ResourceNotFound if target_veteran&.mpi&.icn.blank?
        raise ::Common::Exceptions::Forbidden unless user_is_target_veteran? || user_is_representative?

        render json: { id: target_veteran.mpi.icn }
      end

      protected

      def target_veteran
        ClaimsApi::Veteran.new(
          uuid: params[:ssn],
          ssn: params[:ssn],
          first_name: params[:firstName],
          last_name: params[:lastName],
          va_profile: ClaimsApi::Veteran.build_profile(params[:birthdate]),
          loa: @current_user.loa
        )
      end
    end
  end
end
