# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimSubmissionsController < ApplicationController
      class NotFound < StandardError; end

      def index
        authorize nil, policy_class: SavedClaimClaimantRepresentativePolicy
        serializer = SavedClaimClaimantRepresentativeSerializer.new(claim_submissions)
        render json: ({
          data: serializer.serializable_hash,
          meta: pagination_meta(claim_submissions)
        }.tap do |json|
          include_claimant(json) if params[:id].present?
        end)
      rescue ActiveRecord::RecordNotFound, NotFound
        render json: { error: 'Claimant id not found.' }, status: :not_found
      end

      private

      def include_claimant(json)
        unless Flipper.enabled?(:accredited_representative_portal_claimant_details)
          raise Common::Exceptions::BadRequest.new(detail: 'Claimant details is not enabled.')
        end

        json[:claimant] = {
          'firstName' => claimant_profile.given_names.first,
          'lastName' => claimant_profile.family_name
        }
      end

      def pagination_meta(submissions)
        {
          page: {
            number: submissions.current_page,
            size: submissions.limit_value,
            total: submissions.total_entries,
            totalPages: submissions.total_pages
          }
        }
      end

      def validated_params
        @validated_params ||= params_schema.validate_and_normalize!(params.to_unsafe_h)
      end

      def params_schema
        SubmissionsService::ParamsSchema
      end

      def sort_params
        validated_params.fetch(:sort, {})
      end

      def page
        validated_params.dig(:page, :number)
      end

      def per_page
        validated_params.dig(:page, :size)
      end

      def claim_submissions
        scope = policy_scope(SavedClaimClaimantRepresentative).preload(scope_includes)

        if params[:id].present?
          raise NotFound unless claimant_profile

          scope = scope.where(claimant_id: params[:id])
        end

        scope
          .then { |it| sort_params.present? ? it.sorted_by(sort_params[:by], sort_params[:order]) : it }
          .paginate(page:, per_page:)
      end

      def claimant_profile
        @claimant_profile ||= MPI::Service.new.find_profile_by_identifier(
          identifier: IcnTemporaryIdentifier.lookup_icn(params[:id]),
          identifier_type: MPI::Constants::ICN
        )&.profile
      end

      def scope_includes
        [{ saved_claim: [
          { form_submissions: :form_submission_attempts },
          %i[form_attachment persistent_attachments]
        ] }]
      end
    end
  end
end
