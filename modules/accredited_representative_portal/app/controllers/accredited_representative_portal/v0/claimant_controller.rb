# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimantController < ApplicationController
      before_action :check_feature_toggle

      def search
        authorize nil, policy_class: ClaimantPolicy

        debugger
        poa_requests = policy_scope(PowerOfAttorneyRequest).joins(:claimant).where(claimant: { icn: }).not_withdrawn_more_than_60_days_ago
        active_poa_codes = current_user.user_account.active_power_of_attorney_holders.map(&:poa_code)
        claimant = Claimant.new(search_result.try(:profile), poa_requests, active_poa_codes)

        raise Common::Exceptions::RecordNotFound, 'Claimant not found' unless icn.present? && (
          ClaimantPolicy.new(current_user, claimant).power_of_attorney? || poa_requests.any?
        )

        render json: {
          data: ClaimantSerializer.new(claimant).serializable_hash
        }, status: :ok
      rescue ClaimantSearchService::Error => e
        raise Common::Exceptions::BadRequest.new(detail: e.message, source: ClaimantSearchService)
      end

      private

      def search_result
        @search_result ||= ClaimantSearchService.new(
          params[:first_name], params[:last_name], params[:dob], params[:ssn]
        ).call
      end

      def icn
        search_result.try(:profile).try(:icn)
      end

      def check_feature_toggle
        unless Flipper.enabled?(:accredited_representative_portal_search, @current_user)
          message = 'The accredited_representative_portal_search feature flag is disabled ' \
                    "for the user with uuid: #{@current_user.uuid}"

          raise Common::Exceptions::Forbidden, detail: message
        end
      end
    end
  end
end
