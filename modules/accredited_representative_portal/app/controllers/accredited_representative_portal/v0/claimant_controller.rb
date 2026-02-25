# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimantController < ApplicationController
      BENEFIT_TYPES = %w[compensation pension survivor].freeze

      before_action :validate_benefit_type!, only: :show
      before_action :ensure_claimant_details_enabled!, only: :show

      def search # rubocop:disable Metrics/MethodLength
        authorize nil, policy_class: ClaimantPolicy

        claimant_profile =
          MPI::Service.new.find_profile_by_attributes(
            first_name: params[:first_name],
            last_name: params[:last_name],
            ssn: params[:ssn].try(:gsub, /\D/, ''),
            birth_date: params[:dob]
          ).profile

        claimant_profile.present? or
          raise Common::Exceptions::RecordNotFound, 'Claimant not found'

        claimant_representative =
          ClaimantRepresentative.find(
            claimant_icn: claimant_profile.icn,
            power_of_attorney_holder_memberships:
              current_user.power_of_attorney_holder_memberships
          )

        power_of_attorney_requests =
          policy_scope(PowerOfAttorneyRequest).joins(:claimant).not_withdrawn.where(
            claimant: { icn: claimant_profile.icn }
          )

        (claimant_representative.present? || power_of_attorney_requests.any?) or
          raise Common::Exceptions::RecordNotFound, 'Claimant not found'

        serializer =
          ClaimantSerializer.new(
            power_of_attorney_requests:,
            claimant_representative:,
            claimant_profile:
          )

        data = serializer.serializable_hash
        render json: { data: }
      rescue MPI::Errors::ArgumentError => e
        raise Common::Exceptions::BadRequest.new(
          detail: e.message
        )
      end

      def show
        skip_authorization
        # Using a ClaimantPolicy instance directly here instead of `authorize`
        # so that the ClaimantRepresentative can be re-used and only one call
        # made to the Lighthouse power-of-attorney endpoint for returning
        # the organization name to the user.
        icn = IcnTemporaryIdentifier.lookup_icn(params[:id])
        policy = ClaimantPolicy.new(current_user, icn)
        policy.show? or raise Pundit::NotAuthorizedError

        payload = AccreditedRepresentativePortal::ClaimantDetailsService.new(
          icn:,
          representative_name: policy.claimant_representative.power_of_attorney_holder.name,
          benefit_type_param: params[:benefitType]
        ).call

        render json: payload
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, 'Claimant not found'
      end

      private

      def ensure_claimant_details_enabled!
        return if Flipper.enabled?(:accredited_representative_portal_claimant_details, current_user)

        routing_error
      end

      def validate_benefit_type!
        benefit_type = params[:benefitType]
        return if benefit_type.blank?
        return if BENEFIT_TYPES.include?(benefit_type)

        raise Common::Exceptions::UnprocessableEntity.new(
          detail: "benefitType must be one of: #{BENEFIT_TYPES.join(', ')}"
        )
      end
    end
  end
end
