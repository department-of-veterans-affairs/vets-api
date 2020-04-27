# frozen_string_literal: true

module VIC
  class VICSubmission < ApplicationRecord
    include SetGuid
    include TempFormValidation
    include AsyncRequest

    FORM_ID = 'VIC'

    LOA3_LOCKED_FIELDS = %w[
      veteranFullName
      veteranSocialSecurityNumber
    ].freeze

    attr_accessor(:user)

    validate(:no_forbidden_fields, on: :create)

    after_create(:create_submission_job)
    before_validation(:update_state_to_completed)

    def process_as_anonymous?
      parsed_form['processAsAnonymous']
    end

    private

    def no_forbidden_fields
      if user.present? && user.loa3?
        bad_fields = parsed_form.keys & LOA3_LOCKED_FIELDS

        errors[:form] << "#{bad_fields.to_sentence} fields not allowed for loa3 user" if bad_fields.present?
      end
    end

    def update_state_to_completed
      response_changes = changes['response']

      self.state = 'success' if response_changed? && response_changes[0].blank? && response_changes[1].present?

      true
    end

    def create_submission_job
      SubmissionJob.perform_async(id, form, user&.uuid)
    end
  end
end
