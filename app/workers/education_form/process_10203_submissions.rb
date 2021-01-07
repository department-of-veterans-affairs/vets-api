# frozen_string_literal: true

module EducationForm
  NO_USER = 'no_user'
  DENIED = 'denied'
  PROCESSED = 'processed'
  INIT = 'init'

  class Process10203SubmissionsLogging < StandardError
  end

  class Process10203Submissions
    include Sidekiq::Worker
    include SentryLogging
    # sidekiq_options queue: 'default',
    #                 unique_for: 30.minutes,
    #                 retry: 5

    # Get all 10203 submissions
    def perform(
      records: EducationBenefitsClaim.includes(:saved_claim).where(
        saved_claims: {
          form_id: '22-10203'
        }
      )
    )
      return unless Flipper.enabled?(:stem_automated_decision)

      if records.count.zero?
        log_info('No records to process.')
        return true
      else
        log_info("Processing #{records.count} application(s)")
      end

      user_submissions = group_user_uuid(records)
      process_submissions(user_submissions)
    end

    private

    # Group the submissions by user_uuid or NO_USER
    def group_user_uuid(records)
      records.group_by { |ebc| ebc.education_stem_automated_decision&.user_uuid || NO_USER }
    end

    # If there is NO_USER or the user doesn't have EVSS data mark the 10203 as DENIED
    # If there are multiple submissions for a user compare un-submitted to most recent submission
    # Else check submission data and EVSS data to see if submission can be marked as PROCESSED
    def process_submissions(user_submissions)
      user_submissions.each do |user_uuid, submissions|
        gi_bill_status = if user_uuid == NO_USER
                           nil
                         else
                           get_gi_bill_status(user_uuid)
                         end

        # AC7
        if user_uuid == NO_USER || gi_bill_status&.remaining_entitlement&.blank?
          submissions.each { |submission| update_status(submission, DENIED) }
        else
          # AC 6
          if submissions.count < 1
            check_previous_submissions(submissions, gi_bill_status)
          else
            # AC 5
            process_submission(submissions.first, gi_bill_status)
          end
        end
      end
    end

    # Retrieve EVSS gi_bill_status data for a user
    def get_gi_bill_status(user_uuid)
      user = User.find(user_uuid)
      service = EVSS::GiBillStatus::Service.new(user)
      service.get_gi_bill_status
    rescue => e
      Rails.logger.error "Failed to retrieve GiBillStatus data: #{e.message}"
      {}
    end

    def update_status(submission, status)
      submission.education_stem_automated_decision.automated_decision_state = status
      submission.education_stem_automated_decision.save
    end

    # Makes a list of all submissions that have not been processed and have a status of INIT
    # Finds most recent submission that has already been processed
    #
    # Submissions are marked as processed in EducationForm::CreateDailySpoolFiles
    #
    # For each unprocessed submission compare benefit_left and pursuing_teaching_cert values
    #     to most recent processed submissions
    # If values are the same set status as PROCESSED
    # Else check submission data and EVSS data to see if submission can be marked as PROCESSED
    def check_previous_submissions(submissions, gi_bill_status)
      unprocessed_submissions = submissions.find_all { |ebc| ebc.processed_at.nil? && ebc.education_stem_automated_decision&.automated_decision_state == INIT }
      most_recent_processed = submissions.find_all { |ebc| ebc.processed_at.present? && ebc.education_stem_automated_decision&.automated_decision_state != INIT }
                                         .max_by(&:submitted_at)

      processed_form = format_application(most_recent_processed)

      unprocessed_submissions.each do |submission|
        submission_form = format_application(submission)
        if submission_form.benefit_left == processed_form.benefit_left && submission_form.pursuing_teaching_cert == processed_form.pursuing_teaching_cert
          # AC 6a
          update_status(submission, PROCESSED)
        else
          # AC 6b
          process_submission(submission, gi_bill_status)
        end
      end
    end

    # Set status to DENIED when pursing_teaching_cert in form data is 'no'
    #   or EVSS data for a user shows there is more than 6 months of remaining_entitlement
    def process_submission(submission, gi_bill_status)
      submission_form = format_application(submission)
      status = if submission_form.pursuing_teaching_cert == 'no' || !less_than_six_months?(gi_bill_status)
                 DENIED
               else
                 PROCESSED
                end
      update_status(submission, status)
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

    def less_than_six_months?(gi_bill_status)
      return false if gi_bill_status.remaining_entitlement.blank?

      months = gi_bill_status.remaining_entitlement.months
      days = gi_bill_status.remaining_entitlement.days

      ((months * 30) + days) <= 180
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
