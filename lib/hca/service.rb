# frozen_string_literal: true

require 'common/client/base'
require 'hca/enrollment_system'
require 'hca/configuration'
require 'va1010_forms/enrollment_system/service'

module HCA
  class Service < Common::Client::Base
    include Common::Client::Concerns::Monitoring

    STATSD_KEY_PREFIX = 'api.1010ez'

    configuration HCA::Configuration

    # @param [Hash] user
    def initialize(user = nil)
      @user = user
    end

    # @param [HashWithIndifferentAccess] form JSON form data
    def submit_form(form)
      is_short_form = HealthCareApplication.new(form: form.to_json).short_form?

      with_monitoring do
        VA1010Forms::EnrollmentSystem::Service.new(@user).submit(form, '10-10EZ')
      rescue => e
        increment_failure('submit_form_short_form', e) if is_short_form
        raise e
      ensure
        increment_total('submit_form_short_form') if is_short_form
      end
    end

    def health_check
      submission = VA1010Forms::EnrollmentSystem::Service.soap.build_request(
        :get_form_submission_status,
        message: { formSubmissionId: HCA::Configuration::HEALTH_CHECK_ID }
      )
      response = with_monitoring do
        perform(:post, '', submission.body)
      end
      root = response.body.locate('S:Envelope/S:Body/retrieveFormSubmissionStatusResponse').first
      {
        formSubmissionId: root.locate('formSubmissionId').first.text.to_i,
        timestamp: root.locate('timeStamp').first&.text || Time.now.getlocal.to_s
      }
    end
  end
end
