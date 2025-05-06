# frozen_string_literal: true

require 'sentry_logging'

module EducationForm
  class FormattingError < StandardError
  end

  class Process10203EVSSError < StandardError
  end

  class Process10203Submissions
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options queue: 'default', backtrace: true, unique_for: 24.hours

    # Get all 10203 submissions that have a row in education_stem_automated_decisions
    def perform(
      records: EducationBenefitsClaim.joins(:education_stem_automated_decision).includes(:saved_claim).where(
        saved_claims: {
          form_id: '22-10203'
        }
      ).order('education_benefits_claims.created_at')
    )
      init_count = records.filter do |r|
        r.education_stem_automated_decision.automated_decision_state == EducationStemAutomatedDecision::INIT
      end.count

      if init_count.zero?
        log_info('No records with init status to process.')
        return true
      else
        log_info("Processing #{init_count} application(s) with init status")
      end

      user_submissions = group_user_uuid(records)
      process_user_submissions(user_submissions)
    end

    private

    # Group the submissions by user_uuid
    def group_user_uuid(records)
      records.group_by { |ebc| ebc.education_stem_automated_decision&.user_uuid }
    end

    # If there are multiple submissions for a user compare un-submitted to most recent processed
    #   by EducationForm::CreateDailySpoolFiles
    # Otherwise check submission data and EVSS data to see if submission can be marked as PROCESSED
    def process_user_submissions(user_submissions)
      user_submissions.each_value do |submissions|
        auth_headers = submissions.last.education_stem_automated_decision.auth_headers

        claim_ids = submissions.map(&:id).join(', ')
        log_info "EDIPI available for process STEM claim ids=#{claim_ids}: #{auth_headers&.key?('va_eauth_dodedipnid')}"

        poa = submissions.last.education_stem_automated_decision.poa

        if submissions.count > 1
          check_previous_submissions(submissions, poa)
        else
          process_submission(submissions.first, poa)
        end
      end
    end

    # Ignore already processed either by CreateDailySpoolFiles or this job
    def update_automated_decision(submission, status, poa)
      if submission.processed_at.nil? &&
         submission.education_stem_automated_decision&.automated_decision_state == EducationStemAutomatedDecision::INIT

        submission.education_stem_automated_decision.update(
          automated_decision_state: status,
          poa:
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
    def check_previous_submissions(submissions, user_has_poa)
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
          update_automated_decision(submission, EducationStemAutomatedDecision::PROCESSED, user_has_poa)
        else
          process_submission(submission, user_has_poa)
        end
      end
    end

    def repeat_form?(unprocessed_form, processed_form)
      processed_form.present? &&
        unprocessed_form.enrolled_stem == processed_form.enrolled_stem &&
        unprocessed_form.pursuing_teaching_cert == processed_form.pursuing_teaching_cert &&
        unprocessed_form.benefit_left == processed_form.benefit_left
    end

    # If the user doesn't have EVSS data mark the 10203 as PROCESSED
    # Set status to DENIED when EVSS data for a user shows there is more than 6 months of remaining_entitlement
    #
    # This is only checking EVSS data until form questions that affect setting to DENIED have been reviewed
    def process_submission(submission, user_has_poa)
      remaining_entitlement = submission.education_stem_automated_decision&.remaining_entitlement
      # This code will be updated once QA and additional evaluation is completed
      status = if Settings.vsp_environment != 'production' && more_than_six_months?(remaining_entitlement)
                 EducationStemAutomatedDecision::DENIED
               else
                 EducationStemAutomatedDecision::PROCESSED
               end

      update_automated_decision(submission, status, user_has_poa)
    end

    def format_application(data)
      EducationForm::Forms::VA10203.build(data)
    rescue => e
      inform_on_error(data, e)
      nil
    end

    def remaining_entitlement_days(remaining_entitlement)
      months = remaining_entitlement.months
      days = remaining_entitlement.days
      (months * 30) + days
    end

    # Inverse of less than six months check performed in SavedClaim::EducationBenefits::VA10203
    def more_than_six_months?(remaining_entitlement)
      return false if remaining_entitlement.blank?

      remaining_entitlement_days(remaining_entitlement) > 180
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
