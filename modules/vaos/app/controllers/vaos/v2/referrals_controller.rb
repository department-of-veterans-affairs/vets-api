# frozen_string_literal: true

module VAOS
  module V2
    # ReferralsController provides endpoints for fetching CCRA referrals
    # It uses the Ccra::ReferralService to interact with the underlying CCRA API
    class ReferralsController < VAOS::BaseController
      # GET /v2/referrals
      # Fetches a list of referrals for the current user
      def index
        response = referral_service.get_vaos_referral_list(
          current_user.icn,
          referral_status_param
        )

        # Add encrypted UUIDs to the referrals for URL usage
        add_referral_uuids(response)

        # Filter out expired referrals
        response = filter_expired_referrals(response)

        render json: Ccra::ReferralListSerializer.new(response)
      end

      # GET /v2/referrals/:uuid
      # Fetches a specific referral by its encrypted UUID
      def show
        # Decrypt the referral UUID from the request parameters
        decrypted_id = VAOS::ReferralEncryptionService.decrypt(referral_uuid)

        response = referral_service.get_referral(
          decrypted_id,
          referral_mode_param
        )

        # Add uuid to the detailed response
        response.uuid = referral_uuid

        render json: Ccra::ReferralDetailSerializer.new(response)
      end

      private

      # Adds encrypted UUIDs to referrals for use in URLs to prevent PII in logs
      #
      # @param referrals [Array<Ccra::ReferralListEntry>] The collection of referrals
      # @return [Array<Ccra::ReferralListEntry>] The modified collection
      def add_referral_uuids(referrals)
        return referrals unless referrals.respond_to?(:each)

        referrals.each do |referral|
          # Add encrypted UUID from the referral number
          referral.uuid = VAOS::ReferralEncryptionService.encrypt(referral.referral_number)
        end
      end

      # The encrypted referral UUID from request parameters
      # @return [String] the referral UUID
      def referral_uuid
        params.require(:id)
      end

      # The referral mode parameter (defaults to 'C' if not provided)
      # @return [String] the referral mode
      def referral_mode_param
        # TODO: Need to verify what modes we can allow. API spec is not clear.
        params.fetch(:mode, 'C')
      end

      # CCRA Referral Status Codes:
      # S  - Suspend: Referral temporarily paused/on hold
      # BP - EOC Complete: Episode of Care is completed
      # AP - Approved: Referral approved/authorized for care
      # A  - First Appointment Made: Initial appointment scheduled
      #
      # TODO:
      # I  - Unknown - Possibly means Initial: Referral initiated/in progress
      # AC - Unknown - Possibly means Appointment Canceled
      #
      # The referral status parameter for filtering referrals
      # @return [String] the referral status
      def referral_status_param
        # Default to only show referrals that a veteran can make appointments for
        params.fetch(:status, "'AP','AC','I'")
      end

      # Filters out referrals that have expired (expiration date before today)
      #
      # @param referrals [Array<Ccra::ReferralListEntry>] The collection of referrals
      # @return [Array<Ccra::ReferralListEntry>] Filtered collection without expired referrals
      def filter_expired_referrals(referrals)
        return [] unless referrals.respond_to?(:reject)

        today = Date.current
        referrals.reject { |referral| referral.expiration_date.present? && referral.expiration_date < today }
      end

      # Memoized referral service instance
      # @return [Ccra::ReferralService] the referral service
      def referral_service
        @referral_service ||= Ccra::ReferralService.new(current_user)
      end
    end
  end
end
