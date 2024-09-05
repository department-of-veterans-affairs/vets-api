# frozen_string_literal: true

require 'pension_21p527ez/tag_sentry'
require 'pension_21p527ez/monitor'

module V0
  class PensionClaimsController < ClaimsBaseController
    service_tag 'pension-application'

    def short_name
      'pension_claim'
    end

    def claim_class
      SavedClaim::Pension
    end

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

    # Creates and validates an instance of the class, removing any copies of
    # the form that had been previously saved by the user.
    def create
      Pension21p527ez::TagSentry.tag_sentry

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

    def log_validation_error_to_metadata(in_progress_form, claim)
      return if in_progress_form.blank?

      metadata = in_progress_form.metadata
      metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
      in_progress_form.update(metadata:)
    end

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

    def pension_monitor
      @monitor ||= Pension21p527ez::Monitor.new
    end
  end
end
