# frozen_string_literal: true

require 'pension_burial/tag_sentry'
require 'burials/monitor'

module V0
  class BurialClaimsController < ClaimsBaseController
    service_tag 'burial-application'

    def show
      claim = claim_class.find_by!(guid: params[:id])
      form_submission = claim&.form_submissions&.last
      submission_attempt = form_submission&.form_submission_attempts&.last
      if submission_attempt
        state = submission_attempt.aasm_state == 'failure' ? 'failure' : 'success'
        render(json: { data: { attributes: { state: } } })
      elsif central_mail_submission
        render json: CentralMailSubmissionSerializer.new(central_mail_submission)
      end
    rescue ActiveRecord::RecordNotFound => e
      monitor.track_show404(params[:id], current_user, e)
      render(json: { data: { attributes: { state: 'not found' } } }, status: :not_found)
    rescue => e
      monitor.track_show_error(params[:id], current_user, e)
      render(json: { data: { attributes: { state: 'error processing request' } } }, status: :unprocessable_entity)
    end

    def create
      PensionBurial::TagSentry.tag_sentry

      claim = create_claim
      monitor.track_create_attempt(claim, current_user)

      unless claim.save
        Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
        monitor.track_create_validation_error(in_progress_form, claim, current_user)
        log_validation_error_to_metadata(in_progress_form, claim)
        raise Common::Exceptions::ValidationErrors, claim.errors
      end

      # this method also calls claim.process_attachments!
      claim.submit_to_structured_data_services!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.form_id}"

      in_progress_form = current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
      claim.form_start_date = in_progress_form.created_at if in_progress_form
      monitor.track_create_success(in_progress_form, claim, current_user)

      clear_saved_form(claim.form_id)
      render json: SavedClaimSerializer.new(claim)
    rescue => e
      monitor.track_create_error(in_progress_form, claim, current_user, e)
      raise e
    end

    def create_claim
      if Flipper.enabled?(:va_burial_v2)
        form = filtered_params[:form]
        claim_class.new(form:, formV2: form.present? ? JSON.parse(form)['formV2'] : nil)
      else
        claim_class.new(form: filtered_params[:form])
      end
    end

    def short_name
      'burial_claim'
    end

    def claim_class
      SavedClaim::Burial
    end

    private

    def central_mail_submission
      CentralMailSubmission.joins(:central_mail_claim).find_by(saved_claims: { guid: params[:id] })
    end

    def in_progress_form
      current_user ? InProgressForm.form_for_user(claim.form_id, current_user) : nil
    end

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

    ##
    # retreive a monitor for tracking
    #
    # @return [Burials::Monitor]
    #
    def monitor
      @monitor ||= Burials::Monitor.new
    end
  end
end
