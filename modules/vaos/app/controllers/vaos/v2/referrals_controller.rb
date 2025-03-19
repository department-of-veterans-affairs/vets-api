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

        render json: Ccra::ReferralListSerializer.new(response).serializable_hash
      end

      # GET /v2/referrals/:id
      # Fetches a specific referral by ID
      def show
        response = referral_service.get_referral(
          referral_id,
          referral_mode_param
        )

        render json: Ccra::ReferralDetailSerializer.new(response).serializable_hash
      end

      private

      # The referral ID from request parameters
      # @return [String] the referral ID
      def referral_id
        params.require(:id)
      end

      # The referral mode parameter (defaults to 'C' if not provided)
      # @return [String] the referral mode
      def referral_mode_param
        # TODO: Need to verify what modes we can allow. API spec is not clear.
        params.fetch(:mode, 'C')
      end

      # The referral status parameter for filtering referrals
      # @return [String] the referral status
      def referral_status_param
        # TODO: Need to verify what statuses we can allow. API spec is not clear.
        params.fetch(:status, "'S','BP','AP','AC','A','I'")
      end

      # Memoized referral service instance
      # @return [Ccra::ReferralService] the referral service
      def referral_service
        @referral_service ||= Ccra::ReferralService.new(current_user)
      end
    end
  end
end
