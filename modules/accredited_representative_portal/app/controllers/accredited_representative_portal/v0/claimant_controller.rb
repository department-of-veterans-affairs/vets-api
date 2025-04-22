# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimantController < ApplicationController
      before_action :check_feature_toggle

      def search
        authorize true, policy_class: ClaimantPolicy

        poa_requests = policy_scope(PowerOfAttorneyRequest).joins(:claimant).where(claimant: { icn: })

        raise Common::Exceptions::RecordNotFound, 'Claimant not found' unless icn.present? && (
          ClaimantPolicy.new(current_user, icn).power_of_attorney? || poa_requests.any?
        )

        serializer = ClaimantSerializer.new(search_result.profile, params: { poa_requests:, representative: })

        render json: { data: serializer.serializable_hash }, status: :ok
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

      def representative
        PoaLookupService.new(icn).representative_name
      end

      def scope_includes
        [
          :power_of_attorney_form,
          :power_of_attorney_form_submission,
          :accredited_individual,
          :accredited_organization,
          { resolution: :resolving }
        ]
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
