# frozen_string_literal: true

require 'mail_automation/client'
require 'lighthouse/veterans_health/client'
require 'virtual_regional_office/client'

# rubocop:disable Metrics/ModuleLength
# For use with Form526Submission
module Form526ClaimFastTrackingConcern
  extend ActiveSupport::Concern

  RRD_STATSD_KEY_PREFIX = 'worker.rapid_ready_for_decision'
  MAX_CFI_STATSD_KEY_PREFIX = 'api.max_cfi'
  DISABILITIES_WITH_MAX_CFI = [ClaimFastTracking::DiagnosticCodes::TINNITUS].freeze

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

  DOCUMENT_NAME_PREFIX = 'VAMC'
  DOCUMENT_NAME_SUFFIX = 'Rapid_Decision_Evidence'
  PDF_FILENAME_REGEX = /#{DOCUMENT_NAME_PREFIX}.*#{DOCUMENT_NAME_SUFFIX}/
  RRD_CODE = 'RRD'

  # @return if an RRD pdf has been included as a file to upload
  def rrd_pdf_added_for_uploading?
    form['form526_uploads']&.any? do |upload|
      upload['name']&.match? PDF_FILENAME_REGEX
    end
  end

  def rrd_special_issue_set?
    disabilities = form.dig('form526', 'form526', 'disabilities')
    disabilities.any? do |disability|
      disability['specialIssues']&.include?(RRD_CODE)
    end
  end

  def disabilities
    form.dig('form526', 'form526', 'disabilities')
  end

  def increase_only?
    disabilities.all? { |disability| disability['disabilityActionType']&.upcase == 'INCREASE' }
  end

  def diagnostic_codes
    disabilities.pluck('diagnosticCode')
  end

  def prepare_for_evss!
    begin
      update_classification
    rescue => e
      Rails.logger.error "Contention Classification failed #{e.message}.", backtrace: e.backtrace
    end

    return if pending_eps? || disabilities_not_service_connected?

    save_metadata(forward_to_mas_all_claims: true)
  end

  def update_classification
    return unless Flipper.enabled?(:disability_526_classifier)
    return unless increase_only?
    return unless disabilities.count == 1
    return unless diagnostic_codes.count == 1

    diagnostic_code = diagnostic_codes.first
    params = {
      diagnostic_code:,
      claim_id: saved_claim_id,
      form526_submission_id: id
    }

    classification = classify_by_diagnostic_code(params)
    Rails.logger.info('CLassified 526Submission', id:, saved_claim_id:, classification:)
    update_form_with_classification_code(classification['classification_code']) if classification.present?
  end

  def classify_by_diagnostic_code(params)
    vro_client = VirtualRegionalOffice::Client.new
    response = vro_client.classify_contention_by_diagnostic_code(params)
    response.body
  end

  def update_form_with_classification_code(classification_code)
    form[Form526Submission::FORM_526]['form526']['disabilities'].each do |disability|
      disability['classificationCode'] = classification_code
    end

    update!(form_json: form.to_json)
    invalidate_form_hash
  end

  def log_max_cfi_metrics_on_submit
    DISABILITIES_WITH_MAX_CFI.intersection(diagnostic_codes).each do |diagnostic_code|
      selected_disability = disabilities.find do |dis|
        diagnostic_code == dis['diagnosticCode']
      end
      next if selected_disability.nil?

      next unless max_rated_disabilities_from_ipf.any? do |dis|
        diagnostic_code == dis['diagnostic_code']
      end

      formatted_disability = selected_disability['name'].parameterize(separator: '_')
      max_cfi_enabled = Flipper.enabled?(:disability_526_maximum_rating) ? 'on' : 'off'
      StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.#{max_cfi_enabled}.submit.#{formatted_disability}")
    end
  end

  def send_post_evss_notifications!
    conditionally_notify_mas
    Rails.logger.info('Submitted 526Submission to eVSS', id:, saved_claim_id:, submitted_claim_id:)
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

  def max_rated_disabilities_from_ipf
    in_progress_form = InProgressForm.find_by(form_id: '21-526EZ', user_uuid:)
    return [] if in_progress_form.nil?

    fd = in_progress_form.form_data
    fd = JSON.parse(fd) if fd.is_a?(String)
    rated_disabilities = fd['rated_disabilities'] || []

    rated_disabilities.select do |dis|
      dis['maximum_rating_percentage'] == dis['rating_percentage']
    end
  end

  def open_claims
    icn = UserAccount.where(id: user_account_id).first&.icn
    api_provider = ApiProviderFactory.call(
      type: ApiProviderFactory::FACTORIES[:claims],
      provider: nil,
      options: { auth_headers:, icn: },
      # Flipper id is needed to check if the feature toggle works for this user
      current_user: OpenStruct.new({ flipper_id: user_account_id }),
      feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_CLAIMS_SERVICE
    )

    all_claims = api_provider.all_claims
    all_claims['open_claims']
  end

  # fetch, memoize, and return all of the veteran's rated disabilities from EVSS
  def all_rated_disabilities
    settings = Settings.lighthouse.veteran_verification.form526
    icn = UserAccount.where(id: user_account_id).first&.icn
    api_provider = ApiProviderFactory.call(
      type: ApiProviderFactory::FACTORIES[:rated_disabilities],
      provider: nil,
      options: { auth_headers:, icn: },
      # Flipper id is needed to check if the feature toggle works for this user
      current_user: OpenStruct.new({ flipper_id: user_account_id }),
      feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND
    )

    @all_rated_disabilities ||= begin
      response = api_provider.get_rated_disabilities(settings.access_token.client_id, settings.access_token.rsa_key)
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
    StatsD.increment("#{RRD_STATSD_KEY_PREFIX}.notify_mas.success")
  rescue => e
    send_rrd_alert_email("Failure: MA claim - #{submitted_claim_id}", e.to_s, nil,
                         Settings.rrd.mas_tracking.recipients)
    StatsD.increment("#{RRD_STATSD_KEY_PREFIX}.notify_mas.failure")
  end
end
# rubocop:enable Metrics/ModuleLength
