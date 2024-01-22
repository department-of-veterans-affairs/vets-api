# frozen_string_literal: true

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

      submission = claim.form_submissions&.order(id: :asc)&.last
      attempt = submission&.form_submission_attempts&.order(created_at: :asc)&.last

      if attempt
        # this is to temporarily satisfy frontend check
        # {
        #     "data": {
        #         "id": "12",
        #         "type": "central_mail_submissions",
        #         "attributes": {
        #             "state": "success"
        #             .........
        #         }
        #     }
        # }
        state = attempt.aasm_state == 'failure' ? 'failure' : 'success'
        response = {
          data: {
            id: attempt.id,
            type: 'form_submission_attempts',
            attributes: {
              state:,
              **attempt.attributes
            }
          }
        }
      end

      render(json: response)
    end

    # Creates and validates an instance of the class, removing any copies of
    # the form that had been previously saved by the user.
    def create
      PensionBurial::TagSentry.tag_sentry

      claim = claim_class.new(form: filtered_params[:form])
      user_uuid = current_user&.uuid
      Rails.logger.info("Begin #{claim.class::FORM} Submission", { guid: claim.guid, user_uuid: })

      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.itf_datetime = in_progress_form.created_at if in_progress_form

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        log_validation_error_to_metadata(in_progress_form, claim)
        raise Common::Exceptions::ValidationErrors, claim.errors
      end

      claim.upload_to_lighthouse

      StatsD.increment("#{stats_key}.success")
      Rails.logger.info("Submit #{claim.class::FORM} Success",
                        { confirmation_number: claim.confirmation_number, user_uuid: })

      clear_saved_form(claim.form_id)
      render(json: claim)
    end

    private

    def log_validation_error_to_metadata(in_progress_form, claim)
      return if in_progress_form.blank?

      metadata = in_progress_form.metadata
      metadata['submission']['error_message'] = claim&.errors&.errors&.to_s
      in_progress_form.update(metadata:)
    end
  end
end
