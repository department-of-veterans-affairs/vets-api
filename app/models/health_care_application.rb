# frozen_string_literal: true

class HealthCareApplication < ActiveRecord::Base
  include TempFormValidation
  include SentryLogging

  FORM_ID = '10-10EZ'

  attr_accessor(:user)
  attr_accessor(:async_compatible)

  validates(:state, presence: true, inclusion: %w[success error failed pending])
  validates(:form_submission_id_string, :timestamp, presence: true, if: :success?)

  def success?
    state == 'success'
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
      HCA::SubmissionJob.perform_async(user&.uuid, parsed_form, id)

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
end
