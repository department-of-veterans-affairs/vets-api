# frozen_string_literal: true

require 'dependents_verification/monitor'
require 'dependents_verification/benefits_intake/submit_claim_job'

module DependentsVerification
  module V0
    ###
    # The Dependents Verification claim controller that handles form submissions
    #
    class ClaimsController < ClaimsBaseController
      before_action :check_flipper_flag
      service_tag 'dependents-verification-application'

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'dependents_verification_claim'
      end

      # a subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      def claim_class
        DependentsVerification::SavedClaim
      end

      # GET serialized 0538 dependents verification form data
      def show
        claim = claim_class.find_by!(guid: params[:id]) # raises ActiveRecord::RecordNotFound
        render json: SavedClaimSerializer.new(claim)
      rescue ActiveRecord::RecordNotFound => e
        monitor.track_show404(params[:id], current_user, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        monitor.track_show_error(params[:id], current_user, e)
        raise e
      end

      # POST creates and validates an instance of `claim_class`
      def create
        claim = create_claim(form_data_with_ssn_filenumber.to_json)
        add_va_profile_email_to_claim(claim) if Flipper.enabled?(:lifestage_va_profile_email)
        monitor.track_create_attempt(claim, current_user)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          monitor.track_create_validation_error(in_progress_form, claim, current_user)
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        process_and_upload_to_lighthouse(claim)
        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      # Creates a new claim instance with the provided form parameters.
      #
      # @param form_params [String] The JSON string for the claim form.
      # @return [Claim] A new instance of the claim class initialized with the given attributes.
      #   If the current user has an associated user account, it is included in the claim attributes.
      def create_claim(form_params)
        claim_attributes = { form: form_params }
        claim_attributes[:user_account] = @current_user.user_account if @current_user&.user_account

        claim_class.new(**claim_attributes)
      end

      # Merge the current user's SSN and veteran file number into the form data for PDF generation
      # @return [Hash] the form data with SSN and veteran file number
      def form_data_with_ssn_filenumber
        form_data_as_sym = JSON.parse(filtered_params[:form]).deep_symbolize_keys
        form_data_as_sym[:veteranInformation].merge!(ssn: current_user.ssn, vaFileNumber: veteran_file_number)
        form_data_as_sym
      end

      # Retrieves the veteran's file number from BGS using the current user's participant ID
      # @return [String] the veteran's file number without dashes if it exists
      def veteran_file_number
        file_number = BGS::People::Request.new.find_person_by_participant_id(user: current_user)&.file_number
        file_number_without_dashes = file_number.delete('-') if file_number =~ /\A\d{3}-\d{2}-\d{4}\z/
        file_number_without_dashes || file_number
      end

      # Raises an exception if the dependents verification flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:va_dependents_verification,
                                                                    current_user)
      end

      # Filters out the parameters to form access.
      def filtered_params
        params.require(short_name.to_sym).permit(:form)
      end

      ##
      # Processes attachments for the claim and initiates an async task for intake processing
      #
      # @param in_progress_form [Object]
      # @param claim
      # @raise [Exception]
      def process_and_upload_to_lighthouse(claim)
        DependentsVerification::BenefitsIntake::SubmitClaimJob.perform_async(claim.id)
      end

      ##
      # include validation error on in_progress_form metadata.
      # `noop` if in_progress_form is `blank?`
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [DependentsVerification::SavedClaim]
      #
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      # Inserts the user's VA profile email into the form data
      #
      # @param claim [DependentsVerification::SavedClaim] the claim to update
      # @return [void]
      def add_va_profile_email_to_claim(claim)
        va_profile_email = current_user&.va_profile_email
        return unless va_profile_email

        form_data_hash = JSON.parse(claim.form)
        form_data_hash['va_profile_email'] = va_profile_email
        claim.form = form_data_hash.to_json
      rescue => e
        monitor.track_add_va_profile_email_error(claim, current_user, e)
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [DependentsVerification::Monitor]
      #
      def monitor
        @monitor ||= DependentsVerification::Monitor.new
      end
    end
  end
end
