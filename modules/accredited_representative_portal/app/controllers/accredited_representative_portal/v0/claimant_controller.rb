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

      def show
        authorize nil, policy_class: ClaimantPolicy

        profile = claimant_profile(params[:id])
        raise Common::Exceptions::RecordNotFound, 'Claimant not found' if profile.blank?

        render json: claimant_payload(profile)
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, 'Claimant not found'
      end

      private

      def claimant_profile(id)
        icn = IcnTemporaryIdentifier.find(id).icn
        MPI::Service.new.find_profile_by_identifier(
          identifier: icn,
          identifier_type: MPI::Constants::ICN
        )&.profile
      end

      def claimant_payload(profile)
        {
          data: {
            first_name: profile.given_names&.first,
            last_name: profile.family_name,
            birth_date: profile.birth_date,
            ssn: profile.ssn,
            phone: profile.home_phone,
            address: claimant_address(profile)
          }
        }
      end

      def claimant_address(profile)
        addr = profile.address
        {
          line1: addr&.street,
          line2: addr&.street2,
          city: addr&.city,
          state: addr&.state,
          zip: addr&.postal_code
        }
      end
    end
  end
end
