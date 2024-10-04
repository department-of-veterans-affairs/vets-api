# frozen_string_literal: true

require 'hca/service'
require 'hca/rate_limited_search'
require 'hca/user_attributes'
require 'hca/enrollment_eligibility/service'
require 'hca/enrollment_eligibility/status_matcher'
require 'mpi/service'

class HealthCareApplication < ApplicationRecord
  include SentryLogging
  include VA1010Forms::Utils

  FORM_ID = '10-10EZ'
  ACTIVEDUTY_ELIGIBILITY = 'TRICARE'
  DISABILITY_THRESHOLD = 50
  LOCKBOX = Lockbox.new(key: Settings.lockbox.master_key, encode: true)

  attr_accessor :user, :async_compatible, :google_analytics_client_id, :form

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

  def form_id
    self.class::FORM_ID.upcase
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

  def submit_sync
    @parsed_form = override_parsed_form(parsed_form)

    result = begin
      HCA::Service.new(user).submit_form(parsed_form)
    rescue Common::Client::Errors::ClientError => e
      log_exception_to_sentry(e)

      raise Common::Exceptions::BackendServiceException.new(
        nil, detail: e.message
      )
    end

    Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"

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

    if email.present? || async_compatible
      save!
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
  end

  def form_submission_id
    form_submission_id_string&.to_i
  end

  def parsed_form
    @parsed_form ||= form.present? ? JSON.parse(form) : nil
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
    submission_job = email.present? ? 'SubmissionJob' : 'AnonSubmissionJob'
    @parsed_form = override_parsed_form(parsed_form)

    "HCA::#{submission_job}".constantize.perform_async(
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

  def log_submission_failure_details
    return if parsed_form.blank?

    PersonalInformationLog.create!(
      data: parsed_form,
      error_class: 'HealthCareApplication FailedWontRetry'
    )

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

  def send_failure_email
    first_name = parsed_form.dig('veteranFullName', 'first')
    template_id = Settings.vanotify.services.health_apps_1010.template_id.form1010_ez_failure_email
    api_key = Settings.vanotify.services.health_apps_1010.api_key

    salutation = first_name ? "Dear #{first_name}," : ''

    VANotify::EmailJob.perform_async(
      email,
      template_id,
      { 'salutation' => salutation },
      api_key
    )
    StatsD.increment("#{HCA::Service::STATSD_KEY_PREFIX}.submission_failure_email_sent")
  rescue => e
    log_exception_to_sentry(e)
  end

  def form_matches_schema
    if form.present?
      JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[self.class::FORM_ID], parsed_form).each do |v|
        errors.add(:form, v.to_s)
      end
    end
  end
end
