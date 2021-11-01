# frozen_string_literal: true

require 'evss/disability_compensation_auth_headers'
require 'evss/auth_headers'

module ClaimsApi
  module V2
    class ApplicationController < ::OpenidApplicationController
      protected

      def auth_headers
        evss_headers = EVSS::DisabilityCompensationAuthHeaders
                       .new(target_veteran)
                       .add_headers(
                         EVSS::AuthHeaders.new(target_veteran).to_h
                       )
        evss_headers['va_eauth_pnid'] = target_veteran.mpi.profile.ssn

        if request.headers['Mock-Override'] &&
           Settings.claims_api.disability_claims_mock_override
          evss_headers['Mock-Override'] = request.headers['Mock-Override']
          Rails.logger.info('ClaimsApi: Mock Override Engaged')
        end

        evss_headers
      end

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
        if user_is_representative?
          @target_veteran ||= ClaimsApi::Veteran.new(
            mhv_icn: params[:veteranId],
            loa: @current_user.loa
          )
          # populate missing veteran attributes with their mpi record
          @target_veteran.mpi_record?(user_key: params[:veteranId])
          mpi_profile = @target_veteran.mpi.mvi_response.profile

          @target_veteran[:uuid] = mpi_profile[:ssn]
          @target_veteran[:ssn] = mpi_profile[:ssn]
          @target_veteran[:participant_id] = mpi_profile[:participant_id]
          @target_veteran[:va_profile] = ClaimsApi::Veteran.build_profile(mpi_profile.birth_date)
        else
          @target_veteran ||= ClaimsApi::Veteran.from_identity(identity: @current_user)
        end

        @target_veteran
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

      #
      # Determine if the current authenticated user is allowed access
      #
      # raise if current authenticated user is neither the target veteran, nor target veteran representative
      def verify_access!
        return if user_is_target_veteran? || user_represents_veteran?

        raise ::Common::Exceptions::Forbidden
      end

      #
      # Determine if the current authenticated user is the target veteran's representative
      #
      # @return [boolean] True if the current authenticated user is the target veteran's representative
      def user_represents_veteran?
        reps = ::Veteran::Service::Representative.all_for_user(
          first_name: @current_user.first_name,
          last_name: @current_user.last_name
        )

        return false if reps.blank?
        return false if reps.count > 1

        rep = reps.first
        veteran_poa_code = ::Veteran::User.new(target_veteran)&.power_of_attorney&.code

        return false if veteran_poa_code.blank?

        rep.poa_codes.include?(veteran_poa_code)
      end
    end
  end
end
