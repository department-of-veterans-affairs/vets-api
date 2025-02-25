# frozen_string_literal: true

module ClaimsApi
  module PoaVerification
    extend ActiveSupport::Concern

    included do
      #
      # Validate poa code provided exists in OGC dataset, that provided poa code is a valid/active poa code
      # @param poa_code [String] poa code to validate
      #
      # @raise [Common::Exceptions::InvalidFieldValue] if provided poa code does not exist in OGC dataset
      def validate_poa_code!(poa_code)
        return if valid_poa_code?(poa_code)

        raise ::Common::Exceptions::InvalidFieldValue.new('poaCode', poa_code)
      end

      #
      # Validate poa code provided exists in OGC dataset, that provided poa code is a valid/active poa code
      # @param poa_code [String] poa code to validate
      #
      # @return [Boolean] True if valid poa code, False if not
      def valid_poa_code?(poa_code)
        ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).any?
      end

      #
      # Validate @current_user is an accredited representative
      #
      # @raise [Common::Exceptions::Forbidden] if @current_user is not a representative
      def validate_user_is_accredited!
        representative = ::Veteran::Service::Representative.for_user(first_name: @current_user.first_name,
                                                                     last_name: @current_user.last_name)
        raise ::Common::Exceptions::Forbidden if representative.blank?
      end

      #
      # Validate poa code provided matches one of the poa codes associated with the @current_user
      # @param poa_code [String] poa code to match to @current_user
      #
      # @raise [Common::Exceptions::InvalidFieldValue] if provided poa code is not associated with @current_user
      def validate_poa_code_for_current_user!(poa_code)
        return if valid_poa_code_for_current_user?(poa_code)

        error_msg = 'Veterans making requests do not need to include identifying headers ' \
                    "such as 'X-VA-First-Name'. Please resubmit without extraneous headers"
        raise ::Common::Exceptions::UnprocessableEntity.new(detail: error_msg) if target_veteran_is_current_user?

        raise ::Common::Exceptions::InvalidFieldValue.new('poaCode', poa_code)
      end

      #
      # Request headers are only required if the issuer of the request is *not* the target veteran.
      # If a request is made that unnneccesarily includes headers, we need to check and issue a failure.
      #
      # @return [Boolean] True if current user == request header identity, false if not
      def target_veteran_is_current_user?
        # Certain users might have inconsistencies in naming, so use SSN as a more reliable indicator
        @current_user.ssn == request.headers.fetch('X-VA-SSN')
      end

      #
      # Validate poa code provided matches one of the poa codes associated with the @current_user
      # @param poa_code [String] poa code to match to @current_user
      #
      # @return [Boolean] True if valid poa code, False if not
      def valid_poa_code_for_current_user?(poa_code)
        return false if @current_user.first_name.nil? || @current_user.last_name.nil?

        reps_by_first_and_last_name = ::Veteran::Service::Representative.all_for_user(
          first_name: @current_user.first_name,
          last_name: @current_user.last_name
        )

        exactly_one_rep_match?(reps_by_first_and_last_name, poa_code) ||
          find_by_suffix(poa_code) ||
          find_by_middle_initial(poa_code) ||
          find_by_poa_code(poa_code) ||
          handle_not_found(reps_by_first_and_last_name)
      end

      #
      # Verify @current_user is a valid power of attorney for the Veteran being acted on
      #
      # @raise [Common::Exceptions::Unauthorized] if Veteran is not associated to one of the @current_user's poa codes
      def verify_power_of_attorney!
        return if token.client_credentials_token?

        target_veteran_to_verify = ::Veteran::User.new(target_veteran)
        poa_code_to_verify = target_veteran_to_verify.power_of_attorney.try(:code)
        valid_poa_code_for_current_user?(poa_code_to_verify)
      rescue ::Common::Exceptions::UnprocessableEntity
        raise
      rescue
        raise ::Common::Exceptions::Unauthorized, detail: 'Cannot validate Power of Attorney'
      end

      def poa_code_in_organization?(poa_code)
        ::Veteran::Service::Organization.find_by(poa: poa_code).present?
      end

      private

      def exactly_one_rep_match?(reps, poa_code)
        reps.first.poa_codes.include?(poa_code) if reps.count == 1
      end

      def find_by_suffix(poa_code)
        return false if @current_user.suffix.blank?

        last_name_with_suffix = "#{@current_user.last_name} #{@current_user.suffix}"
        reps_by_suffix = ::Veteran::Service::Representative.all_for_user(first_name: @current_user.first_name,
                                                                         last_name: last_name_with_suffix)

        exactly_one_rep_match?(reps_by_suffix, poa_code)
      end

      def find_by_middle_initial(poa_code)
        return false if @current_user.middle_name.blank?

        middle_initial = @current_user.middle_name[0]
        reps_by_middle_initial = ::Veteran::Service::Representative.all_for_user(first_name: @current_user.first_name,
                                                                                 last_name: @current_user.last_name,
                                                                                 middle_initial:)

        exactly_one_rep_match?(reps_by_middle_initial, poa_code)
      end

      def find_by_poa_code(poa_code)
        reps_by_poa_code = ::Veteran::Service::Representative.all_for_user(first_name: @current_user.first_name,
                                                                           last_name: @current_user.last_name,
                                                                           poa_code:)

        exactly_one_rep_match?(reps_by_poa_code, poa_code)
      end

      def handle_not_found(reps)
        raise ::Common::Exceptions::Unauthorized, detail: 'Ambiguous VSO Representative Results' if reps.count > 1

        false
      end
    end
  end
end
