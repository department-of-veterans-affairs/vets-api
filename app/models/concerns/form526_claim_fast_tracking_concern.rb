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
  EP_MERGE_STATSD_KEY_PREFIX = 'worker.ep_merge'

  DISABILITIES_WITH_MAX_CFI = [ClaimFastTracking::DiagnosticCodes::TINNITUS].freeze
  EP_MERGE_BASE_CODES = %w[010 110 020 030 040].freeze

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

  def increase_or_new?
    disabilities.all? do |disability|
      disability['disabilityActionType']&.upcase == 'INCREASE' || disability['disabilityActionType']&.upcase == 'NEW'
    end
  end

  def diagnostic_codes
    disabilities.pluck('diagnosticCode')
  end

  def prepare_for_evss!
    begin
      classification_updated = update_classification!
    rescue => e
      Rails.logger.error "Contention Classification failed #{e.message}.", backtrace: e.backtrace
    end

    prepare_for_ep_merge! if disabilities.count == 1 && increase_only? && classification_updated

    return if pending_eps? || disabilities_not_service_connected?

    save_metadata(forward_to_mas_all_claims: true)
  end

  def prepare_for_ep_merge!
    pending_eps = open_claims.select { |claim| EP_MERGE_BASE_CODES.include?(claim['base_end_product_code']) }
    StatsD.distribution("#{EP_MERGE_STATSD_KEY_PREFIX}.pending_ep_count", pending_eps.count)
    return unless pending_eps.count == 1

    date = Date.strptime(pending_eps.first['date'], '%m/%d/%Y')
    days_ago = (Time.zone.today - date).round
    StatsD.distribution("#{EP_MERGE_STATSD_KEY_PREFIX}.pending_ep_age", days_ago)
    save_metadata(ep_merge_pending_claim_id: pending_eps.first['id'])
  end

  def get_claim_type
    claim_type = disabilities.pick('disabilityActionType').upcase
    if claim_type == 'INCREASE'
      'claim_for_increase'
    else
      'new'
    end
  end

  def update_classification!
    return unless increase_or_new?
    return unless disabilities.count == 1

    claim_type = get_claim_type
    return unless claim_type == 'claim_for_increase' || Flipper.enabled?(:disability_526_classifier_new_claims)

    diagnostic_code = diagnostic_codes.first
    params = {
      diagnostic_code:,
      claim_id: saved_claim_id,
      form526_submission_id: id,
      claim_type:,
      contention_text: disabilities.pick('name')
    }

    classification = classify_single_contention(params)
    Rails.logger.info('Classified 526Submission', id:, saved_claim_id:, classification:, claim_type:)
    return if classification.blank?

    update_form_with_classification_code(classification['classification_code'])
    classification['classification_code'].present?
  end

  def classify_single_contention(params)
    vro_client = VirtualRegionalOffice::Client.new
    response = vro_client.classify_single_contention(params)
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
      next unless disabilities.any? do |dis|
        diagnostic_code == dis['diagnosticCode']
      end

      next unless max_rated_disabilities_from_ipf.any? do |dis|
        diagnostic_code == dis['diagnostic_code']
      end

      user = User.find(user_uuid)
      max_cfi_enabled = Flipper.enabled?(:disability_526_maximum_rating, user) ? 'on' : 'off'
      StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.#{max_cfi_enabled}.submit.#{diagnostic_code}")
    end
  rescue => e
    # Log the exception but but do not fail, otherwise form will not be submitted
    log_exception_to_sentry(e)
  end

  def send_post_evss_notifications!
    conditionally_notify_mas
    conditionally_merge_ep
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
      dis['maximum_rating_percentage'].present? && dis['maximum_rating_percentage'] == dis['rating_percentage']
    end
  end

  # Fetch and memoize all of the veteran's open EPs. Establishing a new EP will make the memoized
  # value outdated if using the same Form526Submission instance.
  def open_claims
    @open_claims ||= begin
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

  def conditionally_merge_ep
    pending_claim_id = read_metadata(:ep_merge_pending_claim_id)
    return unless pending_claim_id.present? && Flipper.enabled?(:disability_526_ep_merge_api)

    vro_client = VirtualRegionalOffice::Client.new
    vro_client.merge_end_products(pending_claim_id:, ep400_id: submitted_claim_id)
  rescue => e
    Rails.logger.error "EP merge request failed #{e.message}.", backtrace: e.backtrace
  end
end
# rubocop:enable Metrics/ModuleLength
