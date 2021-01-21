# frozen_string_literal: true

require 'evss/gi_bill_status/service'
require 'evss/vso_search/service'
require 'sentry_logging'

module EducationForm
  DENIED = 'denied'
  PROCESSED = 'processed'
  INIT = 'init'

  class FormattingError < StandardError
  end

  class Process10203SubmissionsLogging < StandardError
  end

  class Process10203Submissions
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options queue: 'default',
                    unique_for: 30.minutes,
                    retry: 5,
                    backtrace: true

    # Get all 10203 submissions that have a row in education_stem_automated_decisions
    def perform(
      records: EducationBenefitsClaim.joins(:education_stem_automated_decision).includes(:saved_claim).where(
        saved_claims: {
          form_id: '22-10203'
        }
      )
    )
      return false unless Flipper.enabled?(:stem_automated_decision) && evss_is_healthy?

      if records.count.zero?
        log_info('No records to process.')
        return true
      else
        log_info("Processing #{records.count} application(s)")
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
        user = User.find(user_uuid)
        poa = get_user_poa_status(user)
        gi_bill_status = get_gi_bill_status(user)
        if gi_bill_status == {} || gi_bill_status.remaining_entitlement.blank?
          submissions.each do |submission|
            update_automated_decision(submission, PROCESSED, poa)
          end
        elsif submissions.count > 1
          check_previous_submissions(submissions, gi_bill_status, poa)
        else
          process_submission(submissions.first, gi_bill_status, poa)
        end
      end
    end

    # Retrieve EVSS gi_bill_status data for a user
    def get_gi_bill_status(user)
      service = EVSS::GiBillStatus::Service.new(user)
      service.get_gi_bill_status
    rescue => e
      Rails.logger.error "Failed to retrieve GiBillStatus data: #{e.message}"
      {}
    end

    # Retrieve poa status fromEVSS VSOSearch for a user
    def get_user_poa_status(user)
      service = EVSS::VSOSearch::Service.new(user)
      service.get_current_info['userPoaInfoAvailable']
    rescue => e
      Rails.logger.error "Failed to retrieve VSOSearch data: #{e.message}"
      nil
    end

    def update_automated_decision(submission, status, poa)
      submission.education_stem_automated_decision.update(
        automated_decision_state: status,
        poa: poa
      )
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
        ebc.processed_at.nil? && ebc.education_stem_automated_decision&.automated_decision_state == INIT
      end
      most_recent_processed = submissions.find_all do |ebc|
        ebc.processed_at.present? && ebc.education_stem_automated_decision&.automated_decision_state != INIT
      end
                                         .max_by(&:processed_at)

      processed_form = format_application(most_recent_processed) if most_recent_processed.present?

      unprocessed_submissions.each do |submission|
        unprocessed_form = format_application(submission)
        if repeat_form?(unprocessed_form, processed_form)
          update_automated_decision(submission, PROCESSED, user_has_poa)
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

    # Ignore already processed either by CreateDailySpoolFiles or this job
    #
    # Set status to DENIED when isPursuingTeachingCert in form data is 'no' (false)
    #   and isEnrolledStem is 'no' (false)
    #   or EVSS data for a user shows there is more than 6 months of remaining_entitlement
    def process_submission(submission, gi_bill_status, user_has_poa)
      if submission.processed_at.nil? &&
         submission.education_stem_automated_decision&.automated_decision_state == INIT

        submission_form = format_application(submission)
        status = if (!submission_form.enrolled_stem && !submission_form.pursuing_teaching_cert) ||
                    more_than_six_months?(gi_bill_status)
                   DENIED
                 else
                   PROCESSED
                 end
        update_automated_decision(submission, status, user_has_poa)
      end
    end

    def format_application(data)
      # This check was added to ensure that the model passes validation before
      # attempting to build a form from it. This logic should be refactored as
      # part of a larger effort to clean up the spool file generation if that occurs.
      if data.saved_claim.valid?
        EducationForm::Forms::VA10203.build(data)
      else
        inform_on_error(data)
        nil
      end
    rescue => e
      inform_on_error(data, e)
      nil
    end

    # Inverse of less than six months check performed in EducationForm::SendSchoolCertifyingOfficialsEmail
    def more_than_six_months?(gi_bill_status)
      return true if gi_bill_status.remaining_entitlement.blank?

      months = gi_bill_status.remaining_entitlement.months
      days = gi_bill_status.remaining_entitlement.days

      ((months * 30) + days) > 180
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
      log_exception_to_sentry(Process10203SubmissionsLogging.new(message), {}, {}, :info)
    end
  end
end
