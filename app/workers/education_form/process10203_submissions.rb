# frozen_string_literal: true

require 'evss/gi_bill_status/service'
require 'evss/vso_search/service'
require 'sentry_logging'

module EducationForm
  class FormattingError < StandardError
  end

  class Process10203EVSSError < StandardError
  end

  class Process10203Submissions
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options queue: 'default',
                    backtrace: true

    # Get all 10203 submissions that have a row in education_stem_automated_decisions
    def perform(
      records: EducationBenefitsClaim.joins(:education_stem_automated_decision).includes(:saved_claim).where(
        saved_claims: {
          form_id: '22-10203'
        }
      ).order('education_benefits_claims.created_at')
    )
      return false unless evss_is_healthy?

      if records.count.zero?
        log_info('No records to process.')
        return true
      else
        count = records.filter do |r|
          r.education_stem_automated_decision.automated_decision_state == EducationStemAutomatedDecision::INIT
        end.count
        log_info("Processing #{count} application(s) with init status")
      end

      user_submissions = group_user_uuid(records)
      process_user_submissions(user_submissions)
    end

    private

    def evss_is_healthy?
      Settings.evss.mock_claims || EVSS::Service.service_is_up?
    end

    # Group the submissions by user_uuid
    def group_user_uuid(records)
      records.group_by { |ebc| ebc.education_stem_automated_decision&.user_uuid }
    end

    # If the user doesn't have EVSS data mark the 10203 as PROCESSED
    # If there are multiple submissions for a user compare un-submitted to most recent processed
    #   by EducationForm::CreateDailySpoolFiles
    # Otherwise check submission data and EVSS data to see if submission can be marked as PROCESSED
    def process_user_submissions(user_submissions)
      user_submissions.each do |user_uuid, submissions|
        auth_headers = submissions.last.education_stem_automated_decision.auth_headers
        account = Account.find_by(idme_uuid: user_uuid)

        claim_ids = submissions.map(&:id).join(', ')
        log_info "EDIPI available for process STEM claim ids=#{claim_ids}: #{auth_headers&.key?('va_eauth_dodedipnid')}"

        gi_bill_status = get_gi_bill_status(auth_headers)
        # only check EVSS if poa wasn't set on submit
        poa = submissions.last.education_stem_automated_decision.poa || get_user_poa_status(account, auth_headers)

        if gi_bill_status == {} || gi_bill_status.remaining_entitlement.blank?
          submissions.each do |submission|
            update_automated_decision(submission, EducationStemAutomatedDecision::PROCESSED, poa)
          end
        elsif submissions.count > 1
          check_previous_submissions(submissions, gi_bill_status, poa)
        else
          process_submission(submissions.first, gi_bill_status, poa)
        end
      end
    end

    # Retrieve EVSS gi_bill_status data for a user
    def get_gi_bill_status(auth_headers)
      return {} if auth_headers.nil?

      service = EVSS::GiBillStatus::Service.new(nil, auth_headers)
      service.get_gi_bill_status(auth_headers)
    rescue => e
      log_exception_to_sentry(Process10203EVSSError.new("Failed to retrieve GiBillStatus data: #{e.message}"))
      {}
    end

    # Retrieve poa status fromEVSS VSOSearch for a user
    def get_user_poa_status(account, auth_headers)
      # stem_automated_decision feature disables EVSS call  for POA which will be removed in a future PR
      return nil if Flipper.enabled?(:stem_automated_decision)

      return nil if auth_headers.nil?
      return nil unless auth_headers.key?('va_eauth_dodedipnid')

      service = EVSS::VSOSearch::Service.new(nil, auth_headers, account)
      service.get_current_info(auth_headers)['userPoaInfoAvailable']
    rescue => e
      log_exception_to_sentry(
        Process10203EVSSError.new("Failed to retrieve VSOSearch data: #{e.message}")
      )
      nil
    end

    # Ignore already processed either by CreateDailySpoolFiles or this job
    def update_automated_decision(submission, status, poa, remaining_entitlement = nil)
      if submission.processed_at.nil? &&
         submission.education_stem_automated_decision&.automated_decision_state == EducationStemAutomatedDecision::INIT

        submission.education_stem_automated_decision.update(
          automated_decision_state: status,
          poa: poa,
          remaining_entitlement: remaining_entitlement
        )
      end
    end

    # Makes a list of all submissions that have not been processed and have a status of INIT
    # Finds most recent submission that has already been processed
    #
    # Submissions are marked as processed in EducationForm::CreateDailySpoolFiles
    #
    # For each unprocessed submission compare isEnrolledStem, isPursuingTeachingCert, and benefitLeft values
    #     to most recent processed submissions
    # If values are the same set status as PROCESSED
    # Otherwise check submission data and EVSS data to see if submission can be marked as PROCESSED
    def check_previous_submissions(submissions, gi_bill_status, user_has_poa)
      unprocessed_submissions = submissions.find_all do |ebc|
        ebc.processed_at.nil? &&
          ebc.education_stem_automated_decision&.automated_decision_state == EducationStemAutomatedDecision::INIT
      end
      most_recent_processed = submissions.find_all do |ebc|
        ebc.processed_at.present? &&
          ebc.education_stem_automated_decision&.automated_decision_state != EducationStemAutomatedDecision::INIT
      end
                                         .max_by(&:processed_at)

      processed_form = format_application(most_recent_processed) if most_recent_processed.present?

      unprocessed_submissions.each do |submission|
        unprocessed_form = format_application(submission)
        if repeat_form?(unprocessed_form, processed_form)
          update_automated_decision(submission, EducationStemAutomatedDecision::PROCESSED,
                                    user_has_poa, remaining_entitlement_days(gi_bill_status))
        else
          process_submission(submission, gi_bill_status, user_has_poa)
        end
      end
    end

    def repeat_form?(unprocessed_form, processed_form)
      processed_form.present? &&
        unprocessed_form.enrolled_stem == processed_form.enrolled_stem &&
        unprocessed_form.pursuing_teaching_cert == processed_form.pursuing_teaching_cert &&
        unprocessed_form.benefit_left == processed_form.benefit_left
    end

    # Set status to DENIED when EVSS data for a user shows there is more than 6 months of remaining_entitlement
    #
    # This is only checking EVSS data until form questions that affect setting to DENIED have been reviewed
    def process_submission(submission, gi_bill_status, user_has_poa)
      status = if more_than_six_months?(gi_bill_status)
                 EducationStemAutomatedDecision::DENIED
               else
                 EducationStemAutomatedDecision::PROCESSED
               end
      update_automated_decision(submission, status, user_has_poa, remaining_entitlement_days(gi_bill_status))
    end

    def format_application(data)
      EducationForm::Forms::VA10203.build(data)
    rescue => e
      inform_on_error(data, e)
      nil
    end

    def remaining_entitlement_days(gi_bill_status)
      months = gi_bill_status.remaining_entitlement.months
      days = gi_bill_status.remaining_entitlement.days
      months * 30 + days
    end

    # Inverse of less than six months check performed in EducationForm::SendSchoolCertifyingOfficialsEmail
    def more_than_six_months?(gi_bill_status)
      return true if gi_bill_status.remaining_entitlement.blank?

      remaining_entitlement_days(gi_bill_status) > 180
    end

    def inform_on_error(claim, error = nil)
      region = EducationFacility.facility_for(region: :eastern)
      StatsD.increment("worker.education_benefits_claim.failed_formatting.#{region}.22-#{claim.form_type}")
      exception = if error.present?
                    FormattingError.new("Could not format #{claim.confirmation_number}.\n\n#{error}")
                  else
                    FormattingError.new("Could not format #{claim.confirmation_number}")
                  end
      log_exception_to_sentry(exception)
    end

    def log_info(message)
      logger.info(message)
    end
  end
end
