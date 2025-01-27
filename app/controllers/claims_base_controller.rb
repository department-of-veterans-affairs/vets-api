# frozen_string_literal: true

# Abstract base controller for Claims controllers that use the SavedClaim
# and optionally, PersistentAttachment models. Subclasses must have:
#
# * `short_name()`, which returns an identifier that matches the parameter
#    that the form will be set as in the JSON submission.
# * `claim_class()` must return a sublass of SavedClaim, which will run
#    json-schema validations and perform any storage and attachment processing

require 'common/exceptions/validation_errors'

class ClaimsBaseController < ApplicationController
  skip_before_action(:authenticate)
  before_action :load_user, only: :create

  def show
    submission = CentralMailSubmission.joins(:central_mail_claim).find_by(saved_claims: { guid: params[:id] })
    render json: BenefitsIntakeSubmissionSerializer.new(submission)
  end

  # Creates and validates an instance of the class, removing any copies of
  # the form that had been previously saved by the user.
  def create
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
    render json: SavedClaimSerializer.new(claim)
  end

  private

  def filtered_params
    params.require(short_name.to_sym).permit(:form)
  end

  def stats_key
    "api.#{short_name}"
  end
end
