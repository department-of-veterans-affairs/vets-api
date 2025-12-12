# frozen_string_literal: true

require 'vets/shared_logging'

module EducationForm
  class FormattingError < StandardError
  end

  class Create10203ApplicantDecisionLetters
    include Sidekiq::Job
    include Vets::SharedLogging
    sidekiq_options queue: 'default',
                    backtrace: true

    # Get all 10203 submissions that have a row in education_stem_automated_decisions
    def perform(
      records: EducationBenefitsClaim.includes(:saved_claim, :education_stem_automated_decision).where(
        saved_claims: {
          form_id: '22-10203'
        },
        education_stem_automated_decisions: {
          automated_decision_state: EducationStemAutomatedDecision::DENIED,
          denial_email_sent_at: nil
        }
      )
    )
      if records.count.zero?
        log_info('No records to process.')
        return true
      else
        log_info("Processing #{records.count} denied application(s)")
      end

      records.each do |record|
        StemApplicantDenialMailer.build(record, nil).deliver_now
        record.education_stem_automated_decision.update(denial_email_sent_at: Time.zone.now)
      rescue => e
        inform_on_error(record, e)
      end
      true
    end

    private

    def inform_on_error(claim, error = nil)
      region = EducationFacility.facility_for(region: :eastern)
      StatsD.increment("worker.education_benefits_claim.applicant_denial_letter.#{region}.22-#{claim.form_type}")
      exception = FormattingError.new("Could not email denial letter for #{claim.confirmation_number}.\n\n#{error}")
      log_exception_to_sentry(exception)
    end

    def log_info(message)
      logger.info(message)
    end
  end
end
