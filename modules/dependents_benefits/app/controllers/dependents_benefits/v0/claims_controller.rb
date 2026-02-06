# frozen_string_literal: true

require 'bgs/service'
require 'dependents_benefits/claim_processor'
require 'dependents_benefits/generators/claim674_generator'
require 'dependents_benefits/generators/claim686c_generator'
require 'dependents_benefits/monitor'
require 'dependents_benefits/user_data'

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

      # Returns a list of dependents for the current user
      def show
        dependents = create_dependent_service.get_dependents
        dependents[:diaries] = dependency_verification_service.read_diaries
        render json: DependentsBenefits::DependentsSerializer.new(dependents)
      rescue => e
        monitor.track_error_event('Failure fetching dependents data', "#{stats_key}.show_error", error: e.message)
        raise Common::Exceptions::BackendServiceException.new(nil, detail: e.message)
      end

      def create
        claim = create_parent_claim(dependent_params.to_json)

        # Populate the form_start_date from the IPF if available
        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        raise Common::Exceptions::ValidationErrors, claim unless claim.save

        user_data = DependentsBenefits::UserData.new(current_user, claim.parsed_form)

        # Matching parent_claim_id and saved_claim_id indicates this is a parent claim
        SavedClaimGroup.new(claim_group_guid: claim.guid, parent_claim_id: claim.id, saved_claim_id: claim.id,
                            user_data: user_data.get_user_json).save!
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
                                 parent_claim_id: claim.id, claim_id: claim.id,
                                 user_account_uuid: current_user&.user_account_uuid)

        # Enqueue all submission jobs for the created claim.
        DependentsBenefits::ClaimProcessor.enqueue_submissions(claim.id)

        render json: SavedClaimSerializer.new(claim)
      end

      private

      # Limits the allowed parameters for dependents benefits claim submissions
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

      # Creates a new claim instance with the provided form parameters.
      #
      # @param form_params [String] The JSON string for the claim form.
      # @return [Claim] A new instance of the claim class initialized with the given attributes.
      #   If the current user has an associated user account, it is included in the claim attributes.
      def create_parent_claim(form_params)
        claim_attributes = { form: form_params }
        claim_attributes[:user_account] = @current_user.user_account if @current_user&.user_account

        DependentsBenefits::PrimaryDependencyClaim.new(**claim_attributes)
      end

      # Returns the stats key for dependents application events
      def stats_key
        'api.dependents_application'
      end

      # Raises an exception if the dependents verification flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:dependents_module_enabled, current_user)
      end

      # Creates the BGS dependent service for the current user
      def create_dependent_service
        @dependent_service ||= BGS::DependentService.new(current_user)
      end

      # Creates the BGS dependency verification service for the current user
      def dependency_verification_service
        @dependency_verification_service ||= BGS::DependencyVerificationService.new(current_user)
      end

      # Creates a new monitor instance for tracking events
      def monitor
        DependentsBenefits::Monitor.new
      end
    end
  end
end
