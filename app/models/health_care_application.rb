# frozen_string_literal: true

require 'hca/service'
require 'hca/rate_limited_search'
require 'hca/user_attributes'
require 'hca/enrollment_eligibility/service'
require 'hca/enrollment_eligibility/status_matcher'
require 'mpi/service'
require 'hca/overrides_parser'
require 'kafka/sidekiq/event_bus_submission_job'

class HealthCareApplication < ApplicationRecord
  include SentryLogging
  include VA1010Forms::Utils
  include FormValidation

  FORM_ID = '10-10EZ'
  ACTIVEDUTY_ELIGIBILITY = 'TRICARE'
  DISABILITY_THRESHOLD = 50
  DD_ZSF_TAGS = [
    'service:healthcare-application',
    'function: 10-10EZ async form submission'
  ].freeze
  LOCKBOX = Lockbox.new(key: Settings.lockbox.master_key, encode: true)

  attr_accessor :user, :google_analytics_client_id, :form

  validates(:state, presence: true, inclusion: %w[success error failed pending])
  validates(:form_submission_id_string, :timestamp, presence: true, if: :success?)

  validate(:long_form_required_fields, on: :create)

  validates(:form, presence: true, on: :create)
  validate(:form_matches_schema, on: :create)

  after_save :send_failure_email, if: :send_failure_email?
  after_save :log_async_submission_failure, if: :async_submission_failed?

  # @param [Account] user
  # @return [Hash]
  def self.get_user_identifier(user)
    return if user.nil?

    {
      'icn' => user.icn,
      'edipi' => user.edipi
    }
  end

  def success?
    state == 'success'
  end

  def failed?
    state == 'failed'
  end

  def short_form?
    form.present? && parsed_form['lastServiceBranch'].blank?
  end

  def async_submission_failed?
    saved_change_to_attribute?(:state) && failed?
  end

  def email
    return nil if form.blank?

    parsed_form['email']
  end

  def send_failure_email?
    async_submission_failed? && email.present?
  end

  def form_id
    self.class::FORM_ID
  end

  def submit_sync
    @parsed_form = HCA::OverridesParser.new(parsed_form).override

    result = begin
      HCA::Service.new(user).submit_form(parsed_form)
    rescue Common::Client::Errors::ClientError => e
      if Flipper.enabled?(:hca_disable_sentry_logs)
        Rails.logger.error('[10-10EZ] - Error synchronously submitting form', { exception: e, user_loa: user&.loa })
      else
        log_exception_to_sentry(e)
      end

      raise Common::Exceptions::BackendServiceException.new(
        nil, detail: e.message
      )
    end

    set_result_on_success!(result)

    result
  rescue
    log_sync_submission_failure
    raise
  end

  def process!
    prefill_fields

    unless valid?
      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.validation_error")

      StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.validation_error_short_form") if short_form?

      Sentry.set_extras(user_loa: user&.loa)

      PersonalInformationLog.create(
        data: parsed_form,
        error_class: 'HealthCareApplication ValidationError'
      )

      raise(Common::Exceptions::ValidationErrors, self)
    end
    save!

    send_event_bus_event('received')

    if email.present?
      submit_async
    else
      submit_sync
    end
  end

  def self.determine_active_duty(primary_eligibility, veteran)
    primary_eligibility == ACTIVEDUTY_ELIGIBILITY && veteran == 'false'
  end

  def self.determine_non_military(primary_eligibility, veteran, parsed_status)
    if parsed_status == HCA::EnrollmentEligibility::Constants::ACTIVEDUTY &&
       !determine_active_duty(primary_eligibility, veteran)
      HCA::EnrollmentEligibility::Constants::NON_MILITARY
    else
      parsed_status
    end
  end

  EE_DATA_SELECTED_KEYS = %i[
    application_date
    enrollment_date
    preferred_facility
    effective_date
    primary_eligibility
    priority_group
    can_submit_financial_info
  ].freeze

  def self.parsed_ee_data(ee_data, loa3)
    if loa3
      parsed_status = HCA::EnrollmentEligibility::StatusMatcher.parse(
        ee_data[:enrollment_status], ee_data[:ineligibility_reason]
      )

      parsed_status = determine_non_military(
        ee_data[:primary_eligibility], ee_data[:veteran],
        parsed_status
      )

      ee_data.slice(*EE_DATA_SELECTED_KEYS).merge(parsed_status:)
    else
      { parsed_status: if ee_data[:enrollment_status].present?
                         HCA::EnrollmentEligibility::Constants::LOGIN_REQUIRED
                       else
                         HCA::EnrollmentEligibility::Constants::NONE_OF_THE_ABOVE
                       end }
    end
  end

  def self.enrollment_status(icn, loa3)
    parsed_ee_data(
      HCA::EnrollmentEligibility::Service.new.lookup_user(icn),
      loa3
    )
  end

  def self.user_icn(user_attributes)
    HCA::RateLimitedSearch.create_rate_limited_searches(user_attributes) unless Settings.mvi_hca.skip_rate_limit
    MPI::Service.new.find_profile_by_attributes(first_name: user_attributes.first_name,
                                                last_name: user_attributes.last_name,
                                                birth_date: user_attributes.birth_date,
                                                ssn: user_attributes.ssn)&.profile&.icn
  end

  def self.user_attributes(form)
    form ||= {}
    full_name = form['veteranFullName'] || {}

    return_val = HCA::UserAttributes.new(
      first_name: full_name['first'],
      middle_name: full_name['middle'],
      last_name: full_name['last'],
      birth_date: form['veteranDateOfBirth'],
      ssn: form['veteranSocialSecurityNumber'],
      gender: form['gender']
    )

    raise Common::Exceptions::ValidationErrors, return_val unless return_val.valid?

    return_val
  end

  def set_result_on_success!(result)
    update!(
      state: 'success',
      # this is a string because it overflowed the postgres integer limit in one of the tests
      form_submission_id_string: result[:formSubmissionId].to_s,
      timestamp: result[:timestamp]
    )

    send_event_bus_event('sent', result[:formSubmissionId].to_s)
  end

  def form_submission_id
    form_submission_id_string&.to_i
  end

  def parsed_form
    @parsed_form ||= form.present? ? JSON.parse(form) : nil
  end

  def send_event_bus_event(status, next_id = nil)
    return unless Flipper.enabled?(:hca_ez_kafka_submission_enabled)

    begin
      user_icn = user&.icn || self.class.user_icn(self.class.user_attributes(parsed_form))
    rescue
      # if certain user attributes are missing, we can't get an ICN
      user_icn = nil
    end

    Kafka.submit_event(
      icn: user_icn,
      current_id: id,
      submission_name: 'F1010EZ',
      state: status,
      next_id:
    )
  end

  private

  def long_form_required_fields
    return if form.blank? || parsed_form['vaCompensationType'] == 'highDisability'

    %w[
      maritalStatus
      isEnrolledMedicarePartA
      lastServiceBranch
      lastEntryDate
      lastDischargeDate
    ].each do |attr|
      errors.add(:form, "#{attr} can't be null") if parsed_form[attr].nil?
    end
  end

  def prefill_fields
    return if user.blank? || !user.loa3?

    parsed_form.merge!({
      'veteranFullName' => user.full_name_normalized.compact.stringify_keys,
      'veteranDateOfBirth' => user.birth_date,
      'veteranSocialSecurityNumber' => user.ssn_normalized
    }.compact)
  end

  def submit_async
    @parsed_form = HCA::OverridesParser.new(parsed_form).override

    HCA::SubmissionJob.perform_async(
      self.class.get_user_identifier(user),
      HealthCareApplication::LOCKBOX.encrypt(parsed_form.to_json),
      id,
      google_analytics_client_id
    )

    self
  end

  def log_sync_submission_failure
    StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.sync_submission_failed")
    StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.sync_submission_failed_short_form") if short_form?
    log_submission_failure_details
  end

  def log_async_submission_failure
    StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.failed_wont_retry")
    StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.failed_wont_retry_short_form") if short_form?
    log_submission_failure_details
  end

  def log_submission_failure_details # rubocop:disable Metrics/MethodLength
    return if parsed_form.blank?

    send_event_bus_event('error')

    PersonalInformationLog.create!(
      data: parsed_form,
      error_class: 'HealthCareApplication FailedWontRetry'
    )

    if Flipper.enabled?(:hca_disable_sentry_logs)
      Rails.logger.info(
        '[10-10EZ] - HCA total failure',
        {
          first_initial: parsed_form.dig('veteranFullName', 'first')&.[](0) || 'no initial provided',
          middle_initial: parsed_form.dig('veteranFullName', 'middle')&.[](0) || 'no initial provided',
          last_initial: parsed_form.dig('veteranFullName', 'last')&.[](0) || 'no initial provided'
        }
      )
    else
      log_message_to_sentry(
        'HCA total failure',
        :error,
        {
          first_initial: parsed_form.dig('veteranFullName', 'first')&.[](0) || 'no initial provided',
          middle_initial: parsed_form.dig('veteranFullName', 'middle')&.[](0) || 'no initial provided',
          last_initial: parsed_form.dig('veteranFullName', 'last')&.[](0) || 'no initial provided'
        },
        hca: :total_failure
      )
    end
  end

  def send_failure_email
    first_name = parsed_form.dig('veteranFullName', 'first')
    template_id = Settings.vanotify.services.health_apps_1010.template_id.form1010_ez_failure_email
    api_key = Settings.vanotify.services.health_apps_1010.api_key

    salutation = first_name ? "Dear #{first_name}," : ''
    metadata =
      {
        callback_metadata: {
          notification_type: 'error',
          form_number: FORM_ID,
          statsd_tags: DD_ZSF_TAGS
        }
      }

    VANotify::EmailJob.perform_async(email, template_id, { 'salutation' => salutation }, api_key, metadata)
    StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_failure_email_sent")
  rescue => e
    if Flipper.enabled?(:hca_disable_sentry_logs)
      Rails.logger.error('[10-10EZ] - Failure sending Submission Failure Email', { exception: e })
    else
      log_exception_to_sentry(e)
    end
  end

  def form_matches_schema
    if form.present?
      schema = VetsJsonSchema::SCHEMAS[self.class::FORM_ID]
      validation_errors = validate_form_with_retries(schema, parsed_form)
      validation_errors.each do |v|
        errors.add(:form, v.to_s)
      end
    end
  end
end
