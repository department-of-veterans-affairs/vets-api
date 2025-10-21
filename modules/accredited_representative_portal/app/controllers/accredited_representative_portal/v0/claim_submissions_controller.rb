# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimSubmissionsController < ApplicationController
      def index
        authorize nil, policy_class: SavedClaimClaimantRepresentativePolicy
        serializer = SavedClaimClaimantRepresentativeSerializer.new(claim_submissions)
        render json: {
          data: serializer.serializable_hash,
          meta: pagination_meta(claim_submissions)
        }, status: :ok
      end

      private

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
        policy_scope(SavedClaimClaimantRepresentative)
          .then { |it| sort_params.present? ? it.sorted_by(sort_params[:by], sort_params[:order]) : it }
          .preload(scope_includes)
          .paginate(page:, per_page:)
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
