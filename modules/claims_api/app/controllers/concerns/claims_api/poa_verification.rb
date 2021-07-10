# frozen_string_literal: true

require 'bgs/power_of_attorney_verifier'

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

        raise ::Common::Exceptions::InvalidFieldValue.new('poaCode', poa_code)
      end

      #
      # Validate poa code provided matches one of the poa codes associated with the @current_user
      # @param poa_code [String] poa code to match to @current_user
      #
      # @return [Boolean] True if valid poa code, False if not
      def valid_poa_code_for_current_user?(poa_code)
        reps = ::Veteran::Service::Representative.all_for_user(first_name: @current_user.first_name,
                                                               last_name: @current_user.last_name)
        return false if reps.blank?
        raise ::Common::Exceptions::Unauthorized, detail: 'Ambiguous VSO Representative Results' if reps.count > 1

        reps.first.poa_codes.include?(poa_code)
      end

      #
      # Verify @current_user is a valid power of attorney for the Veteran being acted on
      #
      # @raise [Common::Exceptions::Unauthorized] if Veteran is not associated to one of the @current_user's poa codes
      def verify_power_of_attorney!
        logged_in_representative_user = @current_user
        target_veteran_to_be_verified = target_veteran
        verify_representative_and_veteran(logged_in_representative_user, target_veteran_to_be_verified)
      rescue
        raise ::Common::Exceptions::Unauthorized, detail: 'Cannot validate Power of Attorney'
      end

      def verify_representative_and_veteran(logged_in_representative_user, target_veteran_to_be_verified)
        verifying_bgs_service = BGS::PowerOfAttorneyVerifier.new(target_veteran_to_be_verified)
        verifying_bgs_service.verify(logged_in_representative_user)
        true
      end

      def poa_code_in_organization?(poa_code)
        representative = ::Veteran::Service::Representative.where('? = ANY(poa_codes)', poa_code).first
        raise 'Power of Attorney not found' if representative.blank?
        return false if representative.user_types.blank?

        representative.user_types.include?('veteran_service_officer')
      end

      def verify_consent_limitations!
        poa_code = BGS::PowerOfAttorneyVerifier.new(target_veteran).current_poa_code

        if poa_code_in_organization?(poa_code)
          form_code = '21-22'
        else
          form_code = '21-22A'
        end
        representatives = bgs_service.veteran_representative.read_all_veteran_representatives(form_type_code: form_code, veteran_corp_ptcpnt_id: target_veteran.participant_id)
        # 2, possibly 3, scenarios to account for (are they naturally occurring or just a result of bad data in lower environments?):
        # - what if it returns nil? (ie, no result for that form + id combo)
        #     - e.g. Jesse Gray currently has this scenario
        # - what if it returns content but none of it matches with the current POA code?
        #     - e.g. Ralph E Lee and Greg Anderson have this situation
        # - what if the form_code is a false positive? 
        #     - i.e., poa_code_in_organization? says it should be 21-22 but it's actually 21-22A
        #     - Idk if this one actually happens or not
        rep_poa_codes = representatives.map { |rep| rep[:poa_code] }
        
        if !rep_poa_codes.include?(poa_code)
          raise ::Common::Exceptions::Forbidden, detail: "Veteran has not granted access to records protected by Section 7332, Title 38, U.S.C."
        end
      end
    end
  end
end
