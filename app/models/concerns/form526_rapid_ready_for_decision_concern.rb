# frozen_string_literal: true

require 'mail_automation/client'

# rubocop:disable Metrics/ModuleLength
module Form526RapidReadyForDecisionConcern
  extend ActiveSupport::Concern

  def send_rrd_alert_email(subject, message, error = nil, to = Settings.rrd.alerts.recipients)
    body = <<~BODY
      Environment: #{Settings.vsp_environment}<br/>
      Form526Submission.id: #{id}<br/>
      <br/>
      #{message}<br/>
    BODY
    body += "<br/>Error backtrace:\n #{error.backtrace.join(",<br/>\n ")}" if error
    ActionMailer::Base.mail(
      from: ApplicationMailer.default[:from],
      to: to,
      subject: subject,
      body: body
    ).deliver_now
  end

  def notify_mas_tracking
    message = <<~BODY
      #{disabilities.pluck('name', 'diagnosticCode').join(', ')}
      <table border="1" cellspacing="1" cellpadding="5"><thead>
          <tr>
            <td>Benefit Claim Id</td>
            <td>Submission Date</td>
            <td>Submission Time</td>
            <td>Submission ID</td>
          </tr>
        </thead><tbody>
          <tr>
            <td>#{submitted_claim_id}</td>
            <td>#{created_at.to_date}</td>
            <td>#{created_at.strftime '%H:%M:%S'}</td>
            <td>#{id}</td>
          </tr>
        </tbody>
      </table>
    BODY

    send_rrd_alert_email("MA claim - #{diagnostic_codes.join(', ')}", message, nil,
                         Settings.rrd.mas_tracking.recipients)
  end

  def notify_mas
    notify_mas_tracking

    if Flipper.enabled?(:rrd_mas_notification)
      client = MailAutomation::Client.new({
                                            file_number: birls_id,
                                            claim_id: submitted_claim_id,
                                            form526: form
                                          })
      response = client.initiate_apcas_processing
      save_metadata(mas_packetId: response.dig('body', 'packetId'))
    end
  rescue => e
    send_rrd_alert_email("Failure: MA claim - #{submitted_claim_id}", e.to_s, nil,
                         Settings.rrd.mas_tracking.recipients)
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

    return form.dig('rrd_metadata', 'offramp_reason') if form.dig('rrd_metadata', 'offramp_reason').present?

    return 'error' if form.dig('rrd_metadata', 'error').present?

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
    form.dig('rrd_metadata', 'pdf_created') || false
  end

  def rrd_pdf_uploaded_to_s3?
    form.dig('rrd_metadata', 'pdf_guid').present?
  end

  Uploader = RapidReadyForDecision::FastTrackPdfUploadManager
  PDF_FILENAME_REGEX = /#{Uploader::DOCUMENT_NAME_PREFIX}.*#{Uploader::DOCUMENT_NAME_SUFFIX}/.freeze

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

  def forward_to_mas?
    # only use the first diagnostic code because we can only support single-issue claims
    diagnostic_codes.size == 1 &&
      RapidReadyForDecision::Constants::MAS_DISABILITIES.include?(diagnostic_codes.first) &&
      Flipper.enabled?(:rrd_mas_disability_tracking)
  end

  private

  def open_claims
    all_claims = EVSS::ClaimsService.new(auth_headers).all_claims.body
    all_claims['open_claims']
  end

  # @return if this claim submission was processed and fast-tracked by RRD
  def rrd_claim_processed?
    rrd_pdf_added_for_uploading? && rrd_special_issue_set?
  end
end
# rubocop:enable Metrics/ModuleLength
