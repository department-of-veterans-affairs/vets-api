# frozen_string_literal: true

class HealthCareApplication < ActiveRecord::Base
  include TempFormValidation
  include SentryLogging

  FORM_ID = '10-10EZ'

  attr_accessor(:user)
  attr_accessor(:async_compatible)
  attr_accessor(:google_analytics_client_id)

  validates(:state, presence: true, inclusion: %w[success error failed pending])
  validates(:form_submission_id_string, :timestamp, presence: true, if: :success?)
  validate(:discharge_type_correct)

  after_save :send_failure_mail, if: proc { |hca| hca.state_changed? && hca.failed? && hca.parsed_form&.dig('email') }

  def success?
    state == 'success'
  end

  def failed?
    state == 'failed'
  end

  def submit_sync
    result = begin
      HCA::Service.new(user).submit_form(parsed_form)
    rescue HCA::SOAPParser::ValidationError => e
      raise Common::Exceptions::BackendServiceException.new(
        nil, detail: e.message
      )
    rescue Common::Client::Errors::ClientError => e
      log_exception_to_sentry(e)

      raise Common::Exceptions::BackendServiceException.new(
        nil, detail: e.message
      )
    end

    Rails.logger.info "SubmissionID=#{result[:formSubmissionId]}"

    result
  end

  def process!
    raise(Common::Exceptions::ValidationErrors, self) unless valid?

    if parsed_form['email'].present? && async_compatible
      save!
      HCA::SubmissionJob.perform_async(user&.uuid, parsed_form, id, google_analytics_client_id)

      self
    else
      submit_sync
    end
  end

  def set_result_on_success!(result)
    update_attributes!(
      state: 'success',
      # this is a string because it overflowed the postgres integer limit in one of the tests
      form_submission_id_string: result[:formSubmissionId].to_s,
      timestamp: result[:timestamp]
    )
  end

  def form_submission_id
    form_submission_id_string&.to_i
  end

  private

  def discharge_type_correct
    discharge_date = parsed_form.try(:[], 'lastDischargeDate')
    return true if discharge_date.blank?

    future_date = Date.parse(discharge_date) > Time.now.in_time_zone('Central Time (US & Canada)').to_date
    discharge_type_present = parsed_form['dischargeType'].present?

    if future_date
      errors[:form] << 'dischargeType must be blank if the discharge date is in the future' if discharge_type_present
    else
      errors[:form] << 'dischargeType must be selected if discharge date is not in the future' unless discharge_type_present
    end

    true
  end

  def send_failure_mail
    HCASubmissionFailureMailer.build(parsed_form['email'], google_analytics_client_id).deliver_now
  end
end
