# frozen_string_literal: true

require 'mail_automation/client'
require 'lighthouse/veterans_health/client'

# rubocop:disable Metrics/ModuleLength
module Form526RapidReadyForDecisionConcern
  extend ActiveSupport::Concern

  STATSD_KEY_PREFIX = 'worker.rapid_ready_for_decision'

  def send_rrd_alert_email(subject, message, error = nil, to = Settings.rrd.alerts.recipients)
    RrdAlertMailer.build(self, subject, message, error, to).deliver_now
  end

  def read_metadata(key)
    form.dig('rrd_metadata', key.to_s)
  end

  # @param metadata_hash [Hash] to be merged into form_json['rrd_metadata']
  def save_metadata(metadata_hash)
    form['rrd_metadata'] ||= {}
    form['rrd_metadata'].deep_merge!(metadata_hash)

    update!(form_json: JSON.dump(form))
    invalidate_form_hash
    self
  end

  def rrd_status
    return 'processed' if rrd_claim_processed?

    offramp_reason = read_metadata(:offramp_reason)
    return offramp_reason if offramp_reason.present?

    return 'error' if read_metadata(:error).present?

    'unknown'
  end

  # Fetch all claims from EVSS
  # @return [Boolean] whether there are any open EP 020's
  def pending_eps?
    pending = open_claims.any? { |claim| claim['base_end_product_code'] == '020' }
    save_metadata(offramp_reason: 'pending_ep') if pending
    pending
  end

  def rrd_pdf_created?
    read_metadata(:pdf_created) || false
  end

  def rrd_pdf_uploaded_to_s3?
    read_metadata(:pdf_guid).present?
  end

  Uploader = RapidReadyForDecision::FastTrackPdfUploadManager
  PDF_FILENAME_REGEX = /#{Uploader::DOCUMENT_NAME_PREFIX}.*#{Uploader::DOCUMENT_NAME_SUFFIX}/

  # @return if an RRD pdf has been included as a file to upload
  def rrd_pdf_added_for_uploading?
    form['form526_uploads']&.any? do |upload|
      upload['name']&.match? PDF_FILENAME_REGEX
    end
  end

  def rrd_special_issue_set?
    disabilities = form.dig('form526', 'form526', 'disabilities')
    disabilities.any? do |disability|
      disability['specialIssues']&.include?(RapidReadyForDecision::RrdSpecialIssueManager::RRD_CODE)
    end
  end

  def disabilities
    form.dig('form526', 'form526', 'disabilities')
  end

  def diagnostic_codes
    disabilities.map { |disability| disability['diagnosticCode'] }
  end

  def prepare_for_evss!
    return if pending_eps? || disabilities_not_service_connected?

    save_metadata(forward_to_mas_all_claims: true)
  end

  def send_post_evss_notifications!
    send_completed_notification if rrd_job_selector.rrd_applicable?
    conditionally_notify_mas
  end

  # return whether all disabilities on this form are rated as not service-connected
  def disabilities_not_service_connected?
    disabilities.pluck('ratedDisabilityId').all? do |rated_id|
      rated_id.present? && (all_rated_disabilities
                              .find { |rated| rated_id == rated.rated_disability_id }
                              &.decision_code == 'NOTSVCCON')
    end
  end

  private

  def open_claims
    all_claims = EVSS::ClaimsService.new(auth_headers).all_claims.body
    all_claims['open_claims']
  end

  # fetch, memoize, and return all of the veteran's rated disabilities from EVSS
  def all_rated_disabilities
    @all_rated_disabilities ||= begin
      response = EVSS::DisabilityCompensationForm::Service.new(auth_headers).get_rated_disabilities
      response.rated_disabilities
    end
  end

  # @return if this claim submission was processed and fast-tracked by RRD
  def rrd_claim_processed?
    rrd_pdf_added_for_uploading? && rrd_special_issue_set?
  end

  def notify_mas_all_claims_tracking
    RrdMasNotificationMailer.build(self, Settings.rrd.mas_all_claims_tracking.recipients).deliver_now
  end

  def conditionally_notify_mas
    return unless read_metadata(:forward_to_mas_all_claims)

    notify_mas_all_claims_tracking
    client = MailAutomation::Client.new({
                                          file_number: birls_id,
                                          claim_id: submitted_claim_id,
                                          form526: form
                                        })
    response = client.initiate_apcas_processing
    save_metadata(mas_packetId: response.dig('body', 'packetId'))
    StatsD.increment("#{STATSD_KEY_PREFIX}.notify_mas.success")
  rescue => e
    send_rrd_alert_email("Failure: MA claim - #{submitted_claim_id}", e.to_s, nil,
                         Settings.rrd.mas_tracking.recipients)
    StatsD.increment("#{STATSD_KEY_PREFIX}.notify_mas.failure")
  end

  def send_completed_notification
    RrdCompletedMailer.build(self).deliver_now
  end
end
# rubocop:enable Metrics/ModuleLength
