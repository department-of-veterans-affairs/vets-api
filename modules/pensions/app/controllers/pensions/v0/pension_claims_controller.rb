# frozen_string_literal: true

require 'pensions/tag_sentry'
require 'pensions/monitor'

module Pensions
  module V0
    # (see ClaimsBaseController)
    class PensionClaimsController < ClaimsBaseController
      service_tag 'pension-application'

      # an identifier that matches the parameter that the form will be set as in the JSON submission.
      def short_name
        'pension_claim'
      end

      # a sublass of SavedClaim, runs json-schema validations and performs any storage and attachment processing
      def claim_class
        Pensions::SavedClaim
      end

      # GET serialized pension form data
      def show
        claim = claim_class.find_by!(guid: params[:id]) # will raise ActiveRecord::NotFound
        form_submission = claim.form_submissions&.order(id: :asc)&.last
        submission_attempt = form_submission&.form_submission_attempts&.order(created_at: :asc)&.last
        if submission_attempt
          # this is to satisfy frontend check for successful submission
          state = submission_attempt.aasm_state == 'failure' ? 'failure' : 'success'
          response = format_show_response(claim, state, form_submission, submission_attempt)
        end
        render(json: response)
      rescue ActiveRecord::RecordNotFound => e
        pension_monitor.track_show404(params[:id], current_user, e)
        render(json: { error: e.to_s }, status: :not_found)
      rescue => e
        pension_monitor.track_show_error(params[:id], current_user, e)
        raise e
      end

      # POST creates and validates an instance of `claim_class`
      def create
        Pensions::TagSentry.tag_sentry

        claim = claim_class.new(form: filtered_params[:form])
        pension_monitor.track_create_attempt(claim, current_user)

        in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
        claim.form_start_date = in_progress_form.created_at if in_progress_form

        unless claim.save
          pension_monitor.track_create_error(in_progress_form, claim, current_user)
          log_validation_error_to_metadata(in_progress_form, claim)
          raise Common::Exceptions::ValidationErrors, claim.errors
        end

        claim.upload_to_lighthouse(current_user)

        pension_monitor.track_create_success(in_progress_form, claim, current_user)

        clear_saved_form(claim.form_id)
        render json: SavedClaimSerializer.new(claim)
      rescue => e
        pension_monitor.track_create_error(in_progress_form, claim, current_user, e)
        raise e
      end

      private

      ##
      # include validation error on in_progress_form metadata.
      # `noop` if in_progress_form is `blank?`
      #
      # @param in_progress_form [InProgressForm]
      # @param claim [Pensions::SavedClaim]
      #
      def log_validation_error_to_metadata(in_progress_form, claim)
        return if in_progress_form.blank?

        metadata = in_progress_form.metadata
        metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
        in_progress_form.update(metadata:)
      end

      # format GET response
      def format_show_response(claim, state, form_submission, submission_attempt)
        {
          data: {
            id: claim.id,
            form_id: claim.form_id,
            guid: claim.guid,
            attributes: {
              state:,
              benefits_intake_uuid: form_submission.benefits_intake_uuid,
              form_type: form_submission.form_type,
              attempt_id: submission_attempt.id,
              aasm_state: submission_attempt.aasm_state
            }
          }
        }
      end

      ##
      # retreive a monitor for tracking
      #
      # @return [Pensions::Monitor]
      #
      def pension_monitor
        Pensions::Monitor.new
      end
    end
  end
end
