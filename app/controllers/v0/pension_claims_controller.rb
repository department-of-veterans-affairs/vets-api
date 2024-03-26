# frozen_string_literal: true

require 'pension_21p527ez/tag_sentry'

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
      claim = claim_class.find_by!({ guid: params[:id] }) # will raise ActiveRecord::NotFound
      form_submission = claim.form_submissions&.order(id: :asc)&.last
      submission_attempt = form_submission&.form_submission_attempts&.order(created_at: :asc)&.last
      if submission_attempt
        # this is to satisfy frontend check for successful submission
        state = submission_attempt.aasm_state == 'failure' ? 'failure' : 'success'
        response = format_show_response(claim, state, form_submission, submission_attempt)
      end
      render(json: response)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error('21P-527EZ submission not found',
                         { confirmation_number: params[:id], user_uuid: current_user&.uuid, errors: e.message })
      render(json: { error: e.to_s }, status: :not_found)
    rescue => e
      Rails.logger.error('Fetch 21P-527EZ submission failed',
                         { confirmation_number: params[:id], user_uuid: current_user&.uuid, errors: e.message })
      raise e
    end

    # Creates and validates an instance of the class, removing any copies of
    # the form that had been previously saved by the user.
    def create
      StatsD.increment("#{stats_key}.attempt")
      Pension21p527ez::TagSentry.tag_sentry

      claim = claim_class.new(form: filtered_params[:form])
      user_uuid = current_user&.uuid
      Rails.logger.info("Begin #{claim.class::FORM} Submission", { guid: claim.guid, user_uuid: })

      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.itf_datetime = in_progress_form.created_at if in_progress_form

      unless claim.save
        track_create_error(in_progress_form, claim)
        log_validation_error_to_metadata(in_progress_form, claim)
        raise Common::Exceptions::ValidationErrors, claim.errors
      end

      claim.upload_to_lighthouse

      track_create_success(in_progress_form, claim)

      clear_saved_form(claim.form_id)
      render(json: claim)
    rescue => e
      track_create_error(in_progress_form, claim, e)
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

    def track_create_error(in_progress_form, claim, e = nil)
      Rails.logger.error('21P-527EZ submission to Sidekiq failed',
                         { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                           in_progress_form_id: in_progress_form&.id, errors: claim&.errors&.errors,
                           message: e&.message })
      StatsD.increment("#{stats_key}.failure")
    end

    def track_create_success(in_progress_form, claim)
      Rails.logger.info('21P-527EZ submission to Sidekiq success',
                        { confirmation_number: claim&.confirmation_number, user_uuid: current_user&.uuid,
                          in_progress_form_id: in_progress_form&.id })
      StatsD.increment("#{stats_key}.success")
    end
  end
end
