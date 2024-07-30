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

  EP_MERGE_BASE_CODES = %w[010 110 020].freeze
  EP_MERGE_SPECIAL_ISSUE = 'EMP'
  OPEN_STATUSES = [
    'CLAIM RECEIVED',
    'UNDER REVIEW',
    'GATHERING OF EVIDENCE',
    'REVIEW OF EVIDENCE',
    'CLAIM_RECEIVED',
    'INITIAL_REVIEW'
  ].freeze
  CLAIM_REVIEW_BASE_CODES = %w[030 040].freeze
  CLAIM_REVIEW_TYPES = %w[higherLevelReview supplementalClaim].freeze

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
    disabilities.any? do |disability|
      disability['specialIssues']&.include?(RRD_CODE)
    end
  end

  def disabilities
    form.dig('form526', 'form526', 'disabilities')
  end

  def increase_disabilities
    disabilities.select { |disability| disability['disabilityActionType']&.upcase == 'INCREASE' }
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

  def eligible_for_ep_merge?
    user = User.find(user_uuid)
    return true if Flipper.enabled?(:disability_526_ep_merge_multi_contention, user)
    return false unless disabilities.count == 1

    Flipper.enabled?(:disability_526_ep_merge_new_claims, user) ? increase_or_new? : increase_only?
  end

  def prepare_for_evss!
    begin
      is_claim_fully_classified = update_classification!
    rescue => e
      Rails.logger.error "Contention Classification failed #{e.message}."
      Rails.logger.error e.backtrace.join('\n')
    end

    prepare_for_ep_merge! if eligible_for_ep_merge? && is_claim_fully_classified

    return if pending_eps? || disabilities_not_service_connected?

    save_metadata(forward_to_mas_all_claims: true)
  end

  def prepare_for_ep_merge!
    pending_eps = open_claims.select do |claim|
      EP_MERGE_BASE_CODES.include?(claim['base_end_product_code']) && OPEN_STATUSES.include?(claim['status'])
    end
    Rails.logger.info('EP Merge total open EPs', id:, count: pending_eps.count)
    return unless pending_eps.count == 1

    feature_enabled = Flipper.enabled?(:disability_526_ep_merge_api, User.find(user_uuid))
    open_claim_review = open_claim_review?
    Rails.logger.info(
      'EP Merge open EP eligibility',
      { id:, feature_enabled:, open_claim_review:,
        pending_ep_age: claim_age_in_days(pending_eps.first), pending_ep_status: pending_eps.first['status'] }
    )
    if feature_enabled && !open_claim_review
      save_metadata(ep_merge_pending_claim_id: pending_eps.first['id'])
      add_ep_merge_special_issue!
    end
  rescue => e
    Rails.logger.error("EP400 Merge eligibility failed #{e.message}.", backtrace: e.backtrace)
  end

  def get_claim_type
    claim_type = disabilities.pick('disabilityActionType').upcase
    if claim_type == 'INCREASE'
      'claim_for_increase'
    else
      'new'
    end
  end

  # Contact the VRO classifier service to classify the contentions on this form
  # update the form with the classification codes
  # returns true if all of form's contentions were classified
  def update_classification!
    if Flipper.enabled?(:disability_526_classifier_multi_contention)
      update_contention_classification_all!
    else
      update_contention_classification_single_contention!
    end
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
    vro_client = VirtualRegionalOffice::Client.new
    response = vro_client.classify_vagov_contentions(params)
    response.body
  end

  def format_contention_for_vro(disability)
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

  # Submits contention information to the VRO contention classification service
  # adds classification to the form for each contention provided a classification
  def update_contention_classification_all! # rubocop:disable Metrics/MethodLength
    contentions_array = disabilities.map { |disability| format_contention_for_vro(disability) }
    params = {
      claim_id: saved_claim_id,
      form526_submission_id: id,
      contentions: contentions_array
    }
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

  # Submits contention information to the VRO contention classification
  # service for single-contention claims.
  #
  # note: this method is only used for single-contention claims and is
  # deprecated in favor of update_contention_classification_all, which handles
  # both single and multi-contention claims
  def update_contention_classification_single_contention!
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
    user = User.find(user_uuid)
    max_cfi_enabled = Flipper.enabled?(:disability_526_maximum_rating, user) ? 'on' : 'off'
    ClaimFastTracking::DiagnosticCodesForMetrics::DC.each do |diagnostic_code|
      next unless max_rated_diagnostic_codes_from_ipf.include?(diagnostic_code)

      disability_claimed = diagnostic_codes.include?(diagnostic_code)

      if disability_claimed
        StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.#{max_cfi_enabled}.submit.#{diagnostic_code}")
      end
      Rails.logger.info('Max CFI form526 submission',
                        id:, max_cfi_enabled:, disability_claimed:, diagnostic_code:,
                        cfi_checkbox_was_selected: cfi_checkbox_was_selected?,
                        total_increase_conditions: increase_disabilities.count)
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

  # return whether the associated InProgressForm ever logged that the CFI checkbox was selected
  def cfi_checkbox_was_selected?
    return false if in_progress_form.nil?

    ClaimFastTracking::MaxCfiMetrics.new(in_progress_form, {}).create_or_load_metadata['cfiLogged']
  end

  def add_ep_merge_special_issue!
    disabilities.each do |disability|
      disability['specialIssues'] ||= []
      disability['specialIssues'].append(EP_MERGE_SPECIAL_ISSUE).uniq!
    end
    update!(form_json: JSON.dump(form))
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

  # Check both Benefits Claim service and Caseflow Appeals status APIs for open 030 or 040
  # Offramps EP 400 Merge process if any are found, or if anything fails
  def open_claim_review?
    open_claim_review = open_claims.any? do |claim|
      CLAIM_REVIEW_BASE_CODES.include?(claim['base_end_product_code']) && OPEN_STATUSES.include?(claim['status'])
    end
    if open_claim_review
      StatsD.increment("#{EP_MERGE_STATSD_KEY_PREFIX}.open_claim_review")
      return true
    end

    ssn = User.find(user_uuid)&.ssn
    ssn ||= auth_headers['va_eauth_pnid'] if auth_headers['va_eauth_pnidtype'] == 'SSN'
    decision_reviews = Caseflow::Service.new.get_appeals(OpenStruct.new({ ssn: })).body['data']
    StatsD.increment("#{EP_MERGE_STATSD_KEY_PREFIX}.caseflow_api_called")
    decision_reviews.any? do |review|
      CLAIM_REVIEW_TYPES.include?(review['type']) && review['attributes']['active']
    end
  rescue => e
    Rails.logger.error('EP Merge failed open claim review check', backtrace: e.backtrace)
    Rails.logger.error(e.backtrace.join('\n'))
    true
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
    mas_packet_id = response&.body ? response.body['packetId'] : nil
    save_metadata(mas_packetId: mas_packet_id)
    StatsD.increment("#{RRD_STATSD_KEY_PREFIX}.notify_mas.success")
  rescue => e
    send_rrd_alert_email("Failure: MA claim - #{submitted_claim_id}", e.to_s, nil,
                         Settings.rrd.mas_tracking.recipients)
    StatsD.increment("#{RRD_STATSD_KEY_PREFIX}.notify_mas.failure")
  end

  def conditionally_merge_ep
    pending_claim_id = read_metadata(:ep_merge_pending_claim_id)
    return if pending_claim_id.blank?

    vro_client = VirtualRegionalOffice::Client.new
    vro_client.merge_end_products(pending_claim_id:, ep400_id: submitted_claim_id)
  rescue => e
    Rails.logger.error "EP merge request failed #{e.message}.", backtrace: e.backtrace
  end
end
# rubocop:enable Metrics/ModuleLength
