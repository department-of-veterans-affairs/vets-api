# frozen_string_literal: true

require 'pension_burial/tag_sentry'

module V0
  class BurialClaimsController < ClaimsBaseController
    service_tag 'burial-application'

    def show
      submission_attempt = determine_submission_attempt
      if submission_attempt
        state = submission_attempt.aasm_state == 'failure' ? 'failure' : 'success'
        render(json: { data: { attributes: { state: } } })
      elsif central_mail_submission
        render(json: central_mail_submission)
      else
        Rails.logger.error("ActiveRecord::RecordNotFound: Claim submission not found for claim_id: #{params[:id]}")
        render(json: { data: { attributes: { state: 'not found' } } }, status: :not_found)
      end
    rescue => e
      Rails.logger.error(e.to_s)
      render(json: { data: { attributes: { state: 'error processing request' } } }, status: :unprocessable_entity)
    end

    def create
      PensionBurial::TagSentry.tag_sentry

      claim = if Flipper.enabled?(:va_burial_v2)
                # cannot parse a nil form, to pass unit tests do a check for form presence
                form = filtered_params[:form]
                claim_class.new(form:, formV2: form.present? ? JSON.parse(form)['formV2'] : nil)
              else
                claim_class.new(form: filtered_params[:form])
              end

      unless claim.save
        StatsD.increment("#{stats_key}.failure")
        Sentry.set_tags(team: 'benefits-memorial-1') # tag sentry logs with team name
        raise Common::Exceptions::ValidationErrors, claim
      end
      # this method also calls claim.process_attachments!
      claim.submit_to_structured_data_services!

      Rails.logger.info "ClaimID=#{claim.confirmation_number} Form=#{claim.form_id}"
      clear_saved_form(claim.form_id)
      render(json: claim)
    end

    def short_name
      'burial_claim'
    end

    def claim_class
      SavedClaim::Burial
    end

    private

    def determine_submission_attempt
      claim = claim_class.find_by(guid: params[:id])
      form_submission = claim&.form_submissions&.last
      form_submission&.form_submission_attempts&.last
    end

    def central_mail_submission
      CentralMailSubmission.joins(:central_mail_claim).find_by(saved_claims: { guid: params[:id] })
    end
  end
end
