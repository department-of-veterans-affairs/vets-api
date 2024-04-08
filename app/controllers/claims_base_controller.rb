# frozen_string_literal: true

# Abstract base controller for Claims controllers that use the SavedClaim
# and optionally, PersistentAttachment models. Subclasses must have:
#
# * `short_name()`, which returns an identifier that matches the parameter
#    that the form will be set as in the JSON submission.
# * `claim_class()` must return a sublass of SavedClaim, which will run
#    json-schema validations and perform any storage and attachment processing

# Current subclasses are PensionClaim and BurialClaim.

require 'pension_burial/tag_sentry'
require 'common/exceptions/validation_errors'

class ClaimsBaseController < ApplicationController
  skip_before_action(:authenticate)
  before_action :load_user, only: :create

  # Creates and validates an instance of the class, removing any copies of
  # the form that had been previously saved by the user.
  def create
    PensionBurial::TagSentry.tag_sentry

    claim = claim_class.new(form: filtered_params[:form])
    user_uuid = current_user&.uuid
    Rails.logger.info "Begin ClaimGUID=#{claim.guid} Form=#{claim.class::FORM} UserID=#{user_uuid}"
    unless claim.save
      StatsD.increment("#{stats_key}.failure")
      raise Common::Exceptions::ValidationErrors, claim
    end

    claim.process_attachments!

    StatsD.increment("#{stats_key}.success")
    Rails.logger.info "Submitted job ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM} UserID=#{user_uuid}"

    clear_saved_form(claim.form_id)
    render(json: claim)
  end

  def show
    benefits_intake_json
  end

  private

  def filtered_params
    params.require(short_name.to_sym).permit(:form)
  end

  def stats_key
    "api.#{short_name}"
  end

  def returned_json
    submission = CentralMailSubmission.joins(:central_mail_claim).find_by(saved_claims: { guid: params[:id] })
    if submission.present?
      render(json: submission)
    else
      render(json: benefits_intake_json)
    end
  end

  def benefits_intake_json
    claim = SavedClaim::Burial.find_by!(guid: params[:id]) # will raise ActiveRecord::NotFound
    form_submission = claim.form_submissions&.order(id: :asc)&.last
    submission_attempt = form_submission&.form_submission_attempts&.last
    if submission_attempt
      # this is to satisfy frontend check for successful submission
      state = submission_attempt.aasm_state == 'failure' ? 'failure' : 'success'
      render(json: format_show_response(claim, state, form_submission, submission_attempt))
    else
      render(json: CentralMailSubmission.joins(:central_mail_claim).find_by(saved_claims: { guid: params[:id] }))
    end
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
end
