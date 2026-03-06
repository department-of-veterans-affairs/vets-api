# frozen_string_literal: true

require 'lighthouse/benefits_intake/submission_handler/saved_claim'
require 'education_benefits_claims/monitor'
require 'education_benefits_claims/notification_email'

module EducationBenefitsClaims
  # @see BenefitsIntake::SubmissionHandler::SavedClaim
  class SubmissionHandler < ::BenefitsIntake::SubmissionHandler::SavedClaim
    VALID_FORM_IDS = %w[
      22-0989
      22-10278
    ].freeze
    # A little bit of metaprogramming here: we want one handler to handle
    # several different form types. This works fine for all the instance methods
    # but the class method `pending_attempts` is a problem since it's not passed
    # any arguments. So, when registering handlers, we'll dynamically create a
    # subclass specifically for the form_id of interest.
    def self.for_form_id(form_id)
      raise ArgumentError, "Invalid form id type: #{form_id}" unless VALID_FORM_IDS.include?(form_id)

      child_class = Class.new(EducationBenefitsClaims::SubmissionHandler)
      child_class.const_set(:FORM_ID, form_id)
      child_class
    end

    def self.pending_attempts
      Lighthouse::SubmissionAttempt.joins(:submission).where(status: 'pending',
                                                             'lighthouse_submissions.form_id' => self::FORM_ID)
    end

    private

    # BenefitsIntake::SubmissionHandler::SavedClaim#claim_class
    def claim_class
      ::SavedClaim::EducationBenefits
    end

    # BenefitsIntake::SubmissionHandler::SavedClaim#monitor
    def monitor
      @monitor ||= EducationBenefitsClaims::Monitor.new(claim)
    end

    # BenefitsIntake::SubmissionHandler::SavedClaim#notification_email
    def notification_email
      @notification_email ||= EducationBenefitsClaims::NotificationEmail.new(claim.id)
    end

    # handle a failure result
    # inheriting class must assign @avoided before calling `super`
    def on_failure
      @avoided = notification_email.deliver(:error)
      super
    end

    # handle a success result
    def on_success
      notification_email.deliver(:received)
      super
    end

    # handle a stale result
    def on_stale
      true
    end
  end
end
