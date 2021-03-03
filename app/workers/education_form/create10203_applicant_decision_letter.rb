# frozen_string_literal: true

require 'sentry_logging'

module EducationForm
  class FormattingError < StandardError
  end

  class Create10203ApplicantDecisionLetterLogging < StandardError
  end

  class Create10203ApplicantDecisionLetter
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options queue: 'default',
                    backtrace: true

    # Get all 10203 submissions that have a row in education_stem_automated_decisions
    def perform(
      records: EducationBenefitsClaim.processed.joins(:education_stem_automated_decision).includes(:saved_claim).where(
        saved_claims: {
          form_id: '22-10203'
        },
        education_stem_automated_decisions: {
          automated_decision_state: EducationStemAutomatedDecision::DENIED
        }
      )
    )
      return false unless Flipper.enabled?(:stem_automated_decision)

      if records.count.zero?
        log_info('No records to process.')
        true
      else
        log_info("Processing #{records.count} denied application(s)")
      end

      records.each do |record|
        begin
          StemApplicantDenialMailer.build(record, nil).deliver_now
        rescue => e
          inform_on_error(record, e)
        end
      end
    end

    private

    def inform_on_error(claim, error = nil)
      region = EducationFacility.facility_for(region: :eastern)
      StatsD.increment("worker.education_benefits_claim.applicant_denial_letter.#{region}.22-#{claim.form_type}")
      exception = if error.present?
                    FormattingError.new("Could not email denial letter for #{claim.confirmation_number}.\n\n#{error}")
                  else
                    FormattingError.new("Could not email denial letter for #{claim.confirmation_number}")
                  end
      log_exception_to_sentry(exception)
    end

    def log_info(message)
      log_exception_to_sentry(Create10203ApplicantDecisionLetterLogging.new(message),
                              {}, {}, :info)
    end
  end
end
