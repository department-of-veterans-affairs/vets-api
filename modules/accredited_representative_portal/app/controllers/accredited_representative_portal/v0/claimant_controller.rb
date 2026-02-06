# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimantController < ApplicationController
      def search # rubocop:disable Metrics/MethodLength
        authorize nil, policy_class: ClaimantPolicy

        claimant_profile =
          MPI::Service.new.find_profile_by_attributes(
            first_name: search_params[:first_name],
            last_name: search_params[:last_name],
            ssn: search_params[:ssn].try(:gsub, /\D/, ''),
            birth_date: search_params[:birth_date]
          ).profile

        claimant_profile.present? or
          raise Common::Exceptions::RecordNotFound, 'Claimant not found'

        claimant_representative =
          ClaimantRepresentative.find(
            claimant_icn: claimant_profile.icn,
            power_of_attorney_holder_memberships:
              current_user.power_of_attorney_holder_memberships
          )

        ##
        # TODO: Validate how POA requests in different statuses should appear to
        # the user in this resource.
        #
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

      private

      # Accepts both camelCase (from frontend with X-Key-Inflection header) and
      # snake_case parameter formats to handle cases where OliveBranch middleware
      # doesn't transform request params (e.g., when Content-Type isn't application/json)
      def search_params
        @search_params ||= {
          first_name: params[:first_name] || params[:firstName],
          last_name: params[:last_name] || params[:lastName],
          ssn: params[:ssn],
          birth_date: params[:dob] || params[:dateOfBirth] || params[:date_of_birth]
        }
      end
    end
  end
end
