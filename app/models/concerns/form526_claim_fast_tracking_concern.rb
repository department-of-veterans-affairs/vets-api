# frozen_string_literal: true

require 'mail_automation/client'
require 'lighthouse/veterans_health/client'
require 'contention_classification/client'

# rubocop:disable Metrics/ModuleLength
# For use with Form526Submission
module Form526ClaimFastTrackingConcern
  extend ActiveSupport::Concern

  RRD_STATSD_KEY_PREFIX = 'worker.rapid_ready_for_decision'
  MAX_CFI_STATSD_KEY_PREFIX = 'api.max_cfi'
  FLASHES_STATSD_KEY = 'worker.flashes'
  DOCUMENT_TYPE_METRICS_STATSD_KEY_PREFIX = 'worker.document_type_metrics'

  FLASH_PROTOTYPES = ['Amyotrophic Lateral Sclerosis'].freeze
  OPEN_STATUSES = [
    'CLAIM RECEIVED',
    'UNDER REVIEW',
    'GATHERING OF EVIDENCE',
    'REVIEW OF EVIDENCE',
    'CLAIM_RECEIVED',
    'INITIAL_REVIEW'
  ].freeze

  def claim_age_in_days(pending_ep)
    date = if pending_ep.respond_to?(:claim_date)
             Date.strptime(pending_ep.claim_date, '%Y-%m-%d')
           else
             Date.strptime(pending_ep['date'], '%m/%d/%Y')
           end
    (Time.zone.today - date).round
  end

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

  # TODO: Remove? This is unused.
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
    pending = open_claims.any? do |claim|
      claim.base_end_product_code == '020' && claim.status.upcase != 'COMPLETE'
    end
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
    disabilities.any? do |disability|
      disability['specialIssues']&.include?(RRD_CODE)
    end
  end

  def flashes
    form['flashes'] || []
  end

  def disabilities
    form.dig('form526', 'form526', 'disabilities')
  end

  def increase_disabilities
    disabilities.select { |disability| disability['disabilityActionType']&.upcase == 'INCREASE' }
  end

  def diagnostic_codes
    disabilities.pluck('diagnosticCode')
  end

  def prepare_for_evss!
    begin
      update_contention_classification_all!
    rescue => e
      Rails.logger.error("Contention Classification failed #{e.message}.")
      Rails.logger.error(e.backtrace.join('\n'))
    end

    return if pending_eps? || disabilities_not_service_connected?

    save_metadata(forward_to_mas_all_claims: true)
  end

  def update_form_with_classification_codes(classified_contentions)
    classified_contentions.each_with_index do |classified_contention, index|
      if classified_contention['classification_code'].present?
        classification_code = classified_contention['classification_code']
        disabilities[index]['classificationCode'] = classification_code
      end
    end

    update!(form_json: form.to_json)
    invalidate_form_hash
  end

  def classify_vagov_contentions(params)
    cc_client = ContentionClassification::Client.new
    response = cc_client.classify_vagov_contentions_expanded(params)
    response.body
  end

  def format_contention_for_request(disability)
    contention = {
      contention_text: disability['name'],
      contention_type: disability['disabilityActionType']
    }
    contention['diagnostic_code'] = disability['diagnosticCode'] if disability['diagnosticCode']
    contention
  end

  def log_claim_level_metrics(response_body)
    response_body['is_multi_contention_claim'] = disabilities.count > 1
    Rails.logger.info('classifier response for 526Submission', payload: response_body)
  end

  def log_and_halt_if_no_disabilities
    Rails.logger.info("No disabilities found for classification on claim #{id}")
    false
  end

  # Submits contention information to the Contention Classification API service
  # adds classification to the form for each contention provided a classification
  def update_contention_classification_all!
    return log_and_halt_if_no_disabilities if disabilities.blank?

    contentions_array = disabilities.map { |disability| format_contention_for_request(disability) }
    params = { claim_id: saved_claim_id, form526_submission_id: id, contentions: contentions_array }
    classifier_response = classify_vagov_contentions(params)
    log_claim_level_metrics(classifier_response)
    classifier_response['contentions'].each do |contention|
      classification = nil
      if contention.key?('classification_code') && contention.key?('classification_name')
        classification = {
          classification_code: contention['classification_code'],
          classification_name: contention['classification_name']
        }
      end
      # NOTE: claim_type is actually type of contention, but formatting
      # preserved in order to match existing datadog dashboard
      Rails.logger.info('Classified 526Submission',
                        id:, saved_claim_id:, classification:,
                        claim_type: contention['contention_type'])
    end
    update_form_with_classification_codes(classifier_response['contentions'])
    classifier_response['is_fully_classified']
  end

  def log_max_cfi_metrics_on_submit
    max_rated_diagnostic_codes_from_ipf.each do |diagnostic_code|
      disability_claimed = diagnostic_codes.include?(diagnostic_code)
      StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.submit",
                       tags: ["diagnostic_code:#{diagnostic_code}", "claimed:#{disability_claimed}"])
    end
    claimed_max_rated_dcs = max_rated_diagnostic_codes_from_ipf & diagnostic_codes
    Rails.logger.info('Max CFI form526 submission',
                      id:,
                      num_max_rated: max_rated_diagnostic_codes_from_ipf.count,
                      num_max_rated_cfi: claimed_max_rated_dcs.count,
                      total_cfi: increase_disabilities.count,
                      cfi_checkbox_was_selected: cfi_checkbox_was_selected?)
    StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.on_submit",
                     tags: ["claimed:#{claimed_max_rated_dcs.any?}",
                            "has_max_rated:#{max_rated_diagnostic_codes_from_ipf.any?}"])
  rescue => e
    # Log the exception but but do not fail, otherwise form will not be submitted
    log_exception_to_sentry(e)
  end

  def send_post_evss_notifications!
    conditionally_notify_mas
    log_flashes
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

  # return whether the associated InProgressForm ever logged that the CFI checkbox was selected
  def cfi_checkbox_was_selected?
    return false if in_progress_form.nil?

    ClaimFastTracking::MaxCfiMetrics.new(in_progress_form, {}).create_or_load_metadata['cfiLogged']
  end

  private

  def in_progress_form
    @in_progress_form ||= InProgressForm.find_by(form_id: '21-526EZ', user_uuid:)
  end

  def max_rated_disabilities_from_ipf
    return [] if in_progress_form.nil?

    fd = in_progress_form.form_data
    fd = JSON.parse(fd) if fd.is_a?(String)
    rated_disabilities = fd['rated_disabilities'] || []

    rated_disabilities.select do |dis|
      dis['maximum_rating_percentage'].present? && dis['maximum_rating_percentage'] == dis['rating_percentage']
    end
  end

  def max_rated_diagnostic_codes_from_ipf
    max_rated_disabilities_from_ipf.pluck('diagnostic_code')
  end

  # Fetch and memoize all of the veteran's open EPs. Establishing a new EP will make the memoized
  # value outdated if using the same Form526Submission instance.
  def open_claims
    @open_claims ||= begin
      icn = account.icn
      api_provider = ApiProviderFactory.call(
        type: ApiProviderFactory::FACTORIES[:claims],
        provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
        options: { auth_headers:, icn: },
        # Flipper id is needed to check if the feature toggle works for this user
        current_user: OpenStruct.new({ flipper_id: user_account_id }),
        feature_toggle: nil
      )
      all_claims = api_provider.all_claims
      all_claims.open_claims
    end
  end

  # fetch, memoize, and return all of the veteran's rated disabilities from EVSS
  def all_rated_disabilities
    settings = Settings.lighthouse.veteran_verification.form526
    icn = account&.icn
    invoker = 'Form526ClaimFastTrackingConcern#all_rated_disabilities'
    api_provider = ApiProviderFactory.call(
      type: ApiProviderFactory::FACTORIES[:rated_disabilities],
      provider: :lighthouse,
      options: { auth_headers:, icn: },
      # Flipper id is needed to check if the feature toggle works for this user
      current_user: OpenStruct.new({ flipper_id: user_uuid }),
      feature_toggle: nil
    )

    @all_rated_disabilities ||= begin
      response = api_provider.get_rated_disabilities(
        settings.access_token.client_id,
        settings.access_token.rsa_key,
        { invoker: }
      )
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
    mas_packet_id = response&.body ? response.body['packetId'] : nil
    save_metadata(mas_packetId: mas_packet_id)
    StatsD.increment("#{RRD_STATSD_KEY_PREFIX}.notify_mas.success")
  rescue => e
    send_rrd_alert_email("Failure: MA claim - #{submitted_claim_id}", e.to_s, nil,
                         Settings.rrd.mas_tracking.recipients)
    StatsD.increment("#{RRD_STATSD_KEY_PREFIX}.notify_mas.failure")
  end

  def log_flashes
    flash_prototypes = FLASH_PROTOTYPES & flashes
    Rails.logger.info('Flash Prototype Added', { submitted_claim_id:, flashes: }) if flash_prototypes.any?
    flashes.each do |flash|
      StatsD.increment(FLASHES_STATSD_KEY, tags: ["flash:#{flash}", "prototype:#{flash_prototypes.include?(flash)}"])
    end
  rescue => e
    Rails.logger.error("Failed to log Flash Prototypes #{e.message}.", backtrace: e.backtrace)
  end

  def log_document_type_metrics
    return if in_progress_form.blank?

    fd = in_progress_form.form_data
    fd = JSON.parse(fd) if fd.is_a?(String)
    additional_docs_by_type = get_doc_type_counts(fd, 'additionalDocuments')
    private_medical_docs_by_type = get_doc_type_counts(fd, 'privateMedicalRecordAttachments')
    return if additional_docs_by_type.blank? && private_medical_docs_by_type.blank?

    log_doc_type_metrics_for_group(additional_docs_by_type, 'additionalDocuments')
    log_doc_type_metrics_for_group(private_medical_docs_by_type, 'privateMedicalRecordAttachments')

    Rails.logger.info('Form526 evidence document type metrics',
                      id:,
                      additional_docs_by_type:,
                      private_medical_docs_by_type:)
  rescue => e
    # Log the exception but do not fail
    log_exception_to_sentry(e)
  end

  def get_group_docs(form_data, group_key)
    return [] unless form_data.is_a?(Hash)

    form_data.fetch(group_key, form_data.fetch(group_key.underscore, []))
  end

  def get_doc_type_counts(form_data, group_key)
    docs = get_group_docs(form_data, group_key)
    return {} if docs.nil? || !docs.is_a?(Array)

    docs.map do |doc|
      next nil if doc.blank?
      next 'unknown' unless doc.is_a?(Hash)

      doc.fetch('attachmentId', doc.fetch('attachment_id', 'unknown'))
    end.compact
       .group_by(&:itself)
       .transform_values(&:count)
  end

  def log_doc_type_metrics_for_group(doc_type_counts, group_name)
    doc_type_counts.each do |doc_type, count|
      StatsD.increment("#{DOCUMENT_TYPE_METRICS_STATSD_KEY_PREFIX}.#{group_name.underscore}_document_type",
                       count,
                       tags: ["document_type:#{doc_type}", 'source:form526'])
    end
  end
end
# rubocop:enable Metrics/ModuleLength
