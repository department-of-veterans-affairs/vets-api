# frozen_string_literal: true

module VIC
  class VICSubmission < ActiveRecord::Base
    include SetGuid

    LOA3_LOCKED_FIELDS = %w[
      veteranFullName
      veteranSocialSecurityNumber
    ].freeze

    attr_accessor(:form)
    attr_accessor(:user)

    validates(:state, presence: true, inclusion: %w[success failed pending])
    validates(:response, presence: true, if: :success?)
    validate(:form_matches_schema, on: :create)
    validate(:no_forbidden_fields, on: :create)

    after_create(:create_submission_job)
    before_validation(:update_state_to_completed)

    def success?
      state == 'success'
    end

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

    def parsed_form
      @parsed_form ||= JSON.parse(form)
    end

    def update_state_to_completed
      response_changes = changes['response']

      self.state = 'success' if response_changed? && response_changes[0].blank? && response_changes[1].present?

      true
    end

    def form_matches_schema
      errors[:form].concat(JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS['VIC'], parsed_form))
    end

    def create_submission_job
      SubmissionJob.perform_async(id, form, user&.uuid)
    end
  end
end
