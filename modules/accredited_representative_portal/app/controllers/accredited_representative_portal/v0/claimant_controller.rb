# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimantController < ApplicationController
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
        icn = IcnTemporaryIdentifier.lookup_icn(params[:id])
        authorize icn, policy_class: ClaimantPolicy

        payload = AccreditedRepresentativePortal::ClaimantDetailsService.new(
          icn:,
          benefit_type_param: params[:benefitType]
        ).call

        render json: payload
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, 'Claimant not found'
      end
    end
  end
end
