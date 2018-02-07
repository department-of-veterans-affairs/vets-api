# frozen_string_literal: true

module VIC
  class VICSubmission < ActiveRecord::Base
    include SetGuid

    attr_accessor(:form)
    attr_accessor(:user_uuid)

    validates(:state, presence: true, inclusion: %w[success failed pending])
    validates(:response, presence: true, if: :success?)
    validate(:form_matches_schema, on: :create)

    after_create(:create_submission_job)
    before_validation(:update_state_to_completed)

    def success?
      state == 'success'
    end

    private

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
      SubmissionJob.perform_async(id, form, user_uuid)
    end
  end
end
