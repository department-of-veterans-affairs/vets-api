# frozen_string_literal: true

require 'bgsv2/service'
require 'dependents_benefits/claim_processor'
require 'dependents_benefits/generators/claim674_generator'
require 'dependents_benefits/generators/claim686c_generator'
require 'dependents_benefits/monitor'

module DependentsBenefits
  module V0
    ###
    # The Dependents Benefits claim controller that handles form submissions
    #
    class ClaimsController < ClaimsBaseController
      before_action :load_user, only: %i[create show]
      before_action :check_flipper_flag

      wrap_parameters :dependents_application, format: [:json]

      service_tag 'dependent-change'

      def show
        dependents = create_dependent_service.get_dependents
        dependents[:diaries] = dependency_verification_service.read_diaries
        render json: DependentsSerializer.new(dependents)
      rescue => e
        monitor.track_error_event('Failure fetching dependents data', "#{stats_key}.show_error",
                                  { error: e.message })
        raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
      end

      def create
        claim = DependentsBenefits::SavedClaim.new(form: dependent_params.to_json)

        # Populate the form_start_date from the IPF if available
        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        raise Common::Exceptions::ValidationErrors, claim unless claim.save

        # Matching parent_claim_id and saved_claim_id indicates this is a parent claim
        SavedClaimGroup.new(claim_group_guid: claim.guid, parent_claim_id: claim.id, saved_claim_id: claim.id).save!
        form_data = claim.parsed_form

        raise Common::Exceptions::ValidationErrors if !claim.submittable_686? && !claim.submittable_674?

        # Create a 686c claim for dependent benefits
        DependentsBenefits::Generators::Claim686cGenerator.new(form_data, claim.id).generate if claim.submittable_686?

        if claim.submittable_674?
          # Create a 674 claim for student benefits
          form_data.dig('dependents_application', 'student_information')&.each do |student|
            DependentsBenefits::Generators::Claim674Generator.new(form_data, claim.id, student).generate
          end
        end

        monitor.track_info_event('Successfully created claim', "#{stats_key}.create_success",
                                 { claim_id: claim.id, user_account_uuid: current_user&.user_account_uuid })

        proc_id = create_proc_id
        # Enqueue all submission jobs for the created claims
        DependentsBenefits::ClaimProcessor.enqueue_submissions(claim.id, proc_id)

        render json: SavedClaimSerializer.new(claim)
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
          :statement_of_truth_signature,
          :statement_of_truth_certified,
          'view:selectable686_options': {},
          dependents_application: {},
          supporting_documents: []
        )
      end

      def stats_key
        'api.dependents_application'
      end

      # Raises an exception if the dependents verification flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:dependents_module_enabled, current_user)
      end

      def create_dependent_service
        @dependent_service ||= BGS::DependentV2Service.new(current_user)
      end

      def dependency_verification_service
        @dependency_verification_service ||= BGS::DependencyVerificationService.new(current_user)
      end

      def monitor
        DependentsBenefits::Monitor.new
      end

      def create_proc_id
        vnp_response = BGSV2::Service.new(current_user).create_proc(proc_state: 'Started')
        vnp_response[:vnp_proc_id]
      end
    end
  end
end
