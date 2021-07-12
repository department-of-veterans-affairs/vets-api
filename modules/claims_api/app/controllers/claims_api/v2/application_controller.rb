# frozen_string_literal: true

module ClaimsApi
  module V2
    class ApplicationController < ::OpenidApplicationController
      protected

      #
      # For validating the incoming request body
      # @param validator_class [any] Class implementing ActiveModel::Validations
      #
      def validate_request!(validator_class)
        validator = validator_class.validator(params)
        return if validator.valid?

        raise ::Common::Exceptions::ValidationErrorsBadRequest, validator
      end

      #
      # Veteran being acted on.
      #
      # @return [ClaimsApi::Veteran] Veteran to act on
      def target_veteran
        @target_veteran ||= ClaimsApi::Veteran.new(
          mhv_icn: params[:veteranId],
          loa: @current_user.loa
        )
      end

      #
      # Determine if the current authenticated user is an accredited representative
      #
      # @return [boolean] True if current user is an accredited representative, false otherwise
      def user_is_representative?
        ::Veteran::Service::Representative.find_by(
          first_name: @current_user.first_name,
          last_name: @current_user.last_name
        ).present?
      end

      #
      # Determine if the current authenticated user is the Veteran being acted on
      #
      # @return [boolean] True if the current user is the Veteran being acted on, false otherwise
      def user_is_target_veteran?
        return false if params[:veteranId].blank?
        return false if @current_user.icn.blank?
        return false if target_veteran&.mpi&.icn.blank?
        return false unless params[:veteranId] == target_veteran.mpi.icn

        @current_user.icn == target_veteran.mpi.icn
      end
    end
  end
end
