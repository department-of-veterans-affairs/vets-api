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
    unless claim.save
      StatsD.increment("#{stats_key}.failure")
      raise Common::Exceptions::ValidationErrors, claim
    end
    claim.process_attachments!
    StatsD.increment("#{stats_key}.success")
    Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
    clear_saved_form(claim.form_id)
    render(json: claim)
  end

  def show
    render(json: CentralMailSubmission.joins(:central_mail_claim).where(saved_claims: { guid: params[:id] }).take)
  end

  private

  def filtered_params
    params.require(short_name.to_sym).permit(:form)
  end

  def stats_key
    "api.#{short_name}"
  end
end
