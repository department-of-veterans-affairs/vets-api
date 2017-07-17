# frozen_string_literal: true

class ClaimsBaseController < ApplicationController
  skip_before_action(:authenticate)

  def create
    claim = claim_class.new(form: filtered_params[:form])
    unless claim.save
      validation_error = claim.errors.full_messages.join(', ')
      log_message_to_sentry(validation_error, :error, {}, validation: short_name)

      StatsD.increment("#{stats_key}.failure")
      raise Common::Exceptions::ValidationErrors, claim
    end
    claim.process_attachments!
    StatsD.increment("#{stats_key}.success")
    Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.class::FORM}"
    clear_saved_form(claim.form_id)
    render(json: claim)
  end

  private

  def filtered_params
    params.require(short_name.to_sym).permit(:form)
  end

  def stats_key
    "api.#{short_name}"
  end
end
