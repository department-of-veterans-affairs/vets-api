# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class ClaimSubmissionsController < ApplicationController
      class NotFound < StandardError; end

      def index
        authorize nil, policy_class: SavedClaimClaimantRepresentativePolicy
        serializer = SavedClaimClaimantRepresentativeSerializer.new(claim_submissions)
        render json: {
          data: serializer.serializable_hash,
          meta: pagination_meta(claim_submissions)
        }, status: :ok
      rescue ActiveRecord::RecordNotFound, NotFound
        render json: { error: 'Claimant id not found.' }, status: :not_found
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
        scope = policy_scope(SavedClaimClaimantRepresentative)

        if params[:id].present?
          raise NotFound unless claimant_profile

          ids = scope.select { |sccr| saved_claim_matches_claimant?(sccr) }.map(&:id)
          scope = scope.where(id: ids)
        end

        scope
          .then { |it| sort_params.present? ? it.sorted_by(sort_params[:by], sort_params[:order]) : it }
          .preload(scope_includes)
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

      def saved_claim_matches_claimant?(sccr)
        saved_claim = sccr.saved_claim

        first_name = saved_claim&.parsed_form&.[](sccr.claimant_type)&.dig('name', 'first')
        last_name = saved_claim&.parsed_form&.[](sccr.claimant_type)&.dig('name', 'last')
        ssn = saved_claim&.parsed_form&.[](sccr.claimant_type)&.[]('ssn')
        birth_date = saved_claim&.parsed_form&.[](sccr.claimant_type)&.[]('dateOfBirth')&.gsub(/-/, '')
        [
          first_name.present?,
          (first_name&.downcase == claimant_profile.given_names&.first&.downcase),
          last_name.present?,
          (last_name&.downcase == claimant_profile.family_name&.downcase),
          ssn.present?,
          (ssn == claimant_profile.ssn),
          birth_date.present?,
          (birth_date == claimant_profile.birth_date)
        ].all? { |x| x == true }
      end
    end
  end
end
