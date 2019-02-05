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

  after_save :send_failure_mail, if: proc { |hca| hca.state_changed? && hca.failed? && hca.parsed_form&.dig('email') }

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

  def submit_sync
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
  end

  def process!
    raise(Common::Exceptions::ValidationErrors, self) unless valid?

    if parsed_form['email'].present? && async_compatible
      save!
      HCA::SubmissionJob.perform_async(self.class.get_user_identifier(user), parsed_form, id, google_analytics_client_id)

      self
    else
      submit_sync
    end
  end

  def self.user_icn(form)
    MVI::AttrService.new.find_profile(user_attributes(form))&.profile&.icn
  rescue MVI::Errors::Base
    nil
  end

  def self.user_attributes(form)
    full_name = form['veteranFullName']

    OpenStruct.new(
      first_name: full_name['first'],
      middle_name: full_name['middle'],
      last_name: full_name['last'],
      birth_date: form['veteranDateOfBirth'],
      ssn: form['veteranSocialSecurityNumber'].gsub(/\D/, ''),
      gender: form['gender']
    )
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

  def send_failure_mail
    HCASubmissionFailureMailer.build(parsed_form['email'], google_analytics_client_id).deliver_now
  end
end
