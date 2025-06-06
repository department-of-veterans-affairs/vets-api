# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class SubmissionsController < ApplicationController
      skip_after_action :verify_pundit_authorization, only: :index

      def index
        authorize nil, policy_class: SavedClaimClaimantRepresentativePolicy
        serializer = SavedClaimClaimantRepresentativeSerializer.new(form_submissions)
        render json: {
          data: serializer.serializable_hash,
          meta: pagination_meta(form_submissions)
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

      def sort(data)
        if sort_params[:by] == 'submittedDate'
          if sort_params[:order] == 'asc'
            data.sort { |a, b| Date.strptime(a[:submittedDate]) <=> Date.strptime(b[:submittedDate]) }
          elsif sort_params[:order] == 'desc'
            data.sort { |a, b| Date.strptime(b[:submittedDate]) <=> Date.strptime(a[:submittedDate]) }
          end
        else
          data
        end
      end

      def form_submissions
        policy_scope(SavedClaimClaimantRepresentative)
          .then { |it| sort_params.present? ? it.sorted_by(sort_params[:by], sort_params[:order]) : it }
          .preload(scope_includes)
          .paginate(page:, per_page:)
      end

      def scope_includes
        [{ saved_claim: %i[lighthouse_submissions persistent_attachments] }]
      end
    end
  end
end
