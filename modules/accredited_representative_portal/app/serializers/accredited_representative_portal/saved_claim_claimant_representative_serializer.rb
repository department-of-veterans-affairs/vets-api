# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentativeSerializer < ApplicationSerializer
    STATUSES = {
      'pending' => 'awaiting_receipt',
      'failure' => 'processing_error',
      'vbms' => 'received',
      'manually' => 'received'
    }.freeze

    def initialize(object, *args)
      raise ArgumentError, 'Object cannot be nil' if object.nil?

      super
    end

    attribute :submitted_date do |object|
      object.created_at&.to_date&.iso8601
    end

    attribute :first_name do |object|
      object.saved_claim&.parsed_form&.[](object.claimant_type)&.dig('name', 'first')
    end

    attribute :last_name do |object|
      object.saved_claim&.parsed_form&.[](object.claimant_type)&.dig('name', 'last')
    end

    attribute :benefit_type do |object|
      object.saved_claim&.parsed_form&.[]('benefitType')
    end

    attribute :form_type, &:display_form_id

    attribute :packet do |object|
      object.persistent_attachments&.any?
    end

    attribute :confirmation_number do |object|
      object.latest_submission_attempt&.benefits_intake_uuid
    end

    attribute :vbms_status do |object|
      if object.pending_submission_attempt_stale?
        'awaiting_receipt_warning'
      else
        STATUSES.fetch(object.latest_submission_attempt&.aasm_state, 'processing_error')
      end
    end

    attribute :vbms_received_date do |object|
      if STATUSES[object.latest_submission_attempt&.aasm_state] == 'received'
        object.latest_submission_attempt&.lighthouse_updated_at&.to_date&.iso8601
      end
    end
  end
end
