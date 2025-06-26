# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentativeSerializer < ApplicationSerializer
    STATUSES = {
      'pending' => 'awaiting_receipt',
      'failure' => 'processing_error',
      'vbms' => 'received',
      'manually' => 'received'
    }.freeze

    attribute :submitted_date do |object|
      object.created_at.to_date.iso8601
    end

    attribute :first_name do |object|
      object.saved_claim.parsed_form[object.claimant_type].dig('name', 'first')
    end

    attribute :last_name do |object|
      object.saved_claim.parsed_form[object.claimant_type].dig('name', 'last')
    end

    attribute :form_type, &:display_form_id

    attribute :packet do |object|
      object.persistent_attachments.any?
    end

    attribute :confirmation_number, &:guid

    attribute :vbms_status do |object|
      STATUSES[object.latest_submission_attempt&.aasm_state]
    end

    attribute :vbms_received_date do |object|
      if STATUSES[object.latest_submission_attempt&.aasm_state] == 'received'
        object.latest_submission_attempt.lighthouse_updated_at&.to_date&.iso8601
      end
    end
  end
end
