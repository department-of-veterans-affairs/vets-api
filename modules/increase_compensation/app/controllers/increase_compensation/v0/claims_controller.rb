# frozen_string_literal: true

require 'increase_compensation/benefits_intake/submit_claim_job'
require 'increase_compensation/monitor'
require 'increase_compensation/s3_config'
require 'persistent_attachments/sanitizer'
require 'simple_forms_api/form_remediation/uploader'

module IncreaseCompensation
  module V0
    ###
    # The Increase Compensation claim controller that handles form submissions

    class ClaimsController < ClaimsBaseController
      before_action :check_flipper_flag
      service_tag 'increase-compensation-application'

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'increase_compensation_claim'
      end

      # a subclass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      def claim_class
        IncreaseCompensation::SavedClaim
      end

      def form_class
        IncreaseCompensation::PdfFill::Va218940v1
      end

      # GET serialized Increase Compensation form data
      def show
        claim = claim_class.find_by!(guid: params[:id]) # raises ActiveRecord::RecordNotFound

        form_submission_attempt = get_last_form_submission_attempt(claim.guid)
        pdf_url = get_signed_url(claim, form_submission_attempt.created_at.to_date)

        render json: ArchivedClaimSerializer.new(claim, params: { pdf_url: })
      rescue ActiveRecord::RecordNotFound => e
        monitor.track_show404(params[:id], current_user, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        monitor.track_show_error(params[:id], current_user, e)
        raise e
      end

      # POST creates and validates an instance of `claim_class`
      def create
        claim = claim_class.new(form: filtered_params[:form])
        monitor.track_create_attempt(claim, current_user)

        # Issue with 2 8940's in the api, frontend  calls to /in_progess_form/8940 but backend uses `8940V1`
        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id[..6], current_user) : nil

        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          monitor.track_create_validation_error(in_progress_form, claim, current_user)
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        process_attachments(in_progress_form, claim)

        IncreaseCompensation::BenefitsIntake::SubmitClaimJob.perform_async(claim.id, current_user&.user_account_uuid)
        monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)

        form_submission = FormSubmission.create!(form_type: claim.form_id, saved_claim: claim)
        form_submission_attempt = FormSubmissionAttempt.create!(form_submission:, benefits_intake_uuid: claim.guid)
        pdf_url = upload_to_s3(claim, form_submission_attempt.created_at.to_date)

        render json: ArchivedClaimSerializer.new(claim, params: { pdf_url: })
      rescue => e
        monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      # Raises an exception if the Increase Compensation flipper flag isn't enabled.
      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:increase_compensation_form_enabled,
                                                                    current_user)
      end

      ##
      # Processes attachments for the claim
      #
      # @param in_progress_form [Object]
      # @param claim
      # @raise [Exception]
      def process_attachments(in_progress_form, claim)
        claim.process_attachments!
      rescue => e
        monitor.track_process_attachment_error(in_progress_form, claim, current_user)
        raise e
      end

      # Filters out the parameters to form access.
      def filtered_params
        params.require(short_name.to_sym).permit(:form)
      end

      ##
      # include validation error on in_progress_form metadata.
      # `noop` if in_progress_form is `blank?`
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [IncreaseCompensation::SavedClaim]
      #
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      ##
      # retrieve a monitor for tracking
      #
      # @return [IncreaseCompensation::Monitor]
      #
      def monitor
        @monitor ||= IncreaseCompensation::Monitor.new
      end

      # upload to S3 and return a download url
      def upload_to_s3(claim, created_at)
        File.open(claim.to_pdf(claim.guid)) do |file|
          directory = dated_directory_name(claim.form_id, created_at)
          config = IncreaseCompensation::S3Config.new
          sanitized_file = CarrierWave::SanitizedFile.new(file)
          s3_uploader = SimpleFormsApi::FormRemediation::Uploader.new(directory:, config:)
          s3_uploader.store!(sanitized_file)
          s3_uploader.get_s3_link("#{directory}/#{sanitized_file.filename}")
        end
      end

      # returns the url of an already-created PDF
      def get_signed_url(claim, created_at)
        directory = dated_directory_name(claim.form_id, created_at)
        config = IncreaseCompensation::S3Config.new
        s3_uploader = SimpleFormsApi::FormRemediation::Uploader.new(directory:, config:)
        final = overflow?(claim, created_at)
        s3_uploader.get_s3_link("#{directory}/#{claim.form_id}_#{claim.guid}#{final}.pdf")
      end

      # the last submission attempt is used to construct the S3 file path
      def get_last_form_submission_attempt(benefits_intake_uuid)
        FormSubmissionAttempt.where(benefits_intake_uuid:).order(:created_at).last
      end

      # returns a string to append to the filename based on exsistance of overflow pages
      def overflow?(claim, created_at)
        merged_form_data = form_class.new(claim.parsed_form).merge_fields({})
        hash_converter = ::PdfFill::Filler.make_hash_converter(
          claim.form_id,
          form_class,
          created_at,
          {}
        )
        hash_converter.transform_data(form_data: merged_form_data, pdftk_keys: form_class::KEY)
        overflow = hash_converter.extras_generator
        overflow.text? ? '_final' : ''
      end

      # returns e.g. `12.11.25-Form21P-8416`
      def dated_directory_name(form_number, date = Time.now.utc.to_date)
        "#{date.strftime('%-m.%d.%y')}-Form#{form_number}"
      end
    end
  end
end
