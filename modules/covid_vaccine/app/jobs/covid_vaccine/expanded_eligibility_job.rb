# frozen_string_literal: true

require 'sentry_logging'
require 'va_notify/service'

module CovidVaccine
  class ExpandedEligibilityJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options expires_in: 1.day, retry: 10

    INELIGIBLE_STATUSES = ['Dishonorable', 'Bad Conduct'].freeze
    STATSD_ERROR_NAME = 'worker.covid_vaccine_expanded_eligibility.error'
    STATSD_SUCCESS_NAME = 'worker.covid_vaccine_expanded_eligibility.success'

    def perform(record_id)
      submission = CovidVaccine::V0::ExpandedRegistrationSubmission.find(record_id)
      return unless submission.received?

      eligibility_info = {}

      if veteran?(submission)
        eligibility_info.merge!(mpi_lookup(submission))
        # if eligibility_info[:icn].present?
        #   eligibility_info.merge!(emis_eligibility(eligibility_info[:icn]))
        # else
        eligibility_info.merge!(self_eligibility(submission))
        # end
      else
        eligibility_info[:eligible] = true
        eligibility_info[:icn] = nil
      end

      handle_success(submission, eligibility_info)
    rescue => e
      handle_errors(e, record_id)
    end

    def handle_success(submission, eligibility_info)
      submission.eligibility_info = eligibility_info
      if eligibility_info[:eligible]
        submission.eligibility_passed
      else
        submission.eligibility_failed
      end
      submission.save!
      audit_log(submission)
      StatsD.increment(STATSD_SUCCESS_NAME)
    end

    def handle_errors(ex, record_id)
      log_exception_to_sentry(ex, { record_id: record_id })
      StatsD.increment(STATSD_ERROR_NAME)
      raise ex
    end

    private

    def audit_log(submission)
      log_attrs = {
        applicant_type: submission.raw_form_data['applicant_type'],
        eligible: submission.eligibility_info[:eligible],
        ineligible_reason: submission.eligibility_info[:ineligible_reason],
        has_icn: submission.eligibility_info[:icn].present?
      }
      Rails.logger.info('Covid_Vaccine Expanded_Eligibility', log_attrs)
    end

    def veteran?(submission)
      submission.raw_form_data['applicant_type'] == 'veteran'
    end

    def self_eligibility(submission)
      character_of_service = submission.raw_form_data['character_of_service']
      begin_date = submission.raw_form_data['date_range']['from']
      end_date = submission.raw_form_data['date_range']['to']
      if INELIGIBLE_STATUSES.include?(character_of_service)
        return {
          eligible: false,
          ineligible_reason: 'self_reported_character_of_service'
        }
      end
      if months_of_service(begin_date, end_date) < 24
        return {
          eligible: false,
          ineligible_reason: 'self_reported_period_of_service'
        }
      end
      {
        eligible: true,
        ineligible_reason: nil
      }
    end

    def months_of_service(begin_date, end_date)
      begin_year, begin_month, = begin_date.split('-').map(&:to_i)
      end_year, end_month, = end_date.split('-').map(&:to_i)
      12 * (end_year - begin_year) + (end_month - begin_month) + 1
    end

    def mpi_lookup(submission)
      ui = OpenStruct.new(first_name: submission.raw_form_data['first_name'],
                          last_name: submission.raw_form_data['last_name'],
                          birth_date: submission.raw_form_data['birth_date'],
                          ssn: submission.raw_form_data['ssn'],
                          gender: nil,
                          valid?: true)
      timestamp = Time.current
      response = MPI::Service.new.find_profile(ui)
      if response.status == 'OK'
        {
          icn: response.profile.icn,
          mpi_query_timestamp: timestamp
        }
      else
        {
          icn: nil,
          mpi_query_timestamp: timestamp
        }
      end
    end
  end
end
