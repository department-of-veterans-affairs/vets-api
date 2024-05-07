# frozen_string_literal: true

module Mobile
  module V0
    class DependentsController < ApplicationController
      def index
        dependents_response = dependent_service.get_dependents
        persons = dependents_response[:persons].map { |person| Dependent.new(id: SecureRandom.uuid, **person) }

        render json: DependentSerializer.new(persons)
      rescue => e
        raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
      end

      def create
        claim = SavedClaim::DependencyClaim.new(form: dependent_params.to_json)

        unless claim.save
          Raven.tags_context(team: 'mobile') # tag sentry logs with team name
          raise Common::Exceptions::ValidationErrors, claim
        end

        claim.process_attachments!
        response = dependent_service.submit_686c_form(claim)
        new_dependent = NewDependentFormSubmission.new(
          id: SecureRandom.uuid,
          submit_form_job_id: response[:submit_form_job_id]
        )
        serialized = NewDependentFormSubmissionSerializer.new(new_dependent)

        render json: serialized, status: :accepted
      end

      private

      def dependent_params
        params.permit(
          :add_spouse,
          :veteran_was_married_before,
          :add_child,
          :report674,
          :report_divorce,
          :spouse_was_married_before,
          :report_stepchild_not_in_household,
          :report_death,
          :report_marriage_of_child_under18,
          :report_child18_or_older_is_not_attending_school,
          'view:selectable686_options': {},
          dependents_application: {},
          supporting_documents: []
        )
      end

      def dependent_service
        @dependent_service ||= BGS::DependentService.new(current_user)
      end
    end
  end
end
