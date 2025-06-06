# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentativeSerializer < ApplicationSerializer
    STATUSES = {
      'pending' => 'awaiting_receipt',
      'submitted' => 'awaiting_receipt',
      'failure' => 'processing_error',
      'vbms' => 'received',
      'manually' => 'received'
    }.freeze

    attribute :submitted_date do |object|
      object.created_at.to_date.iso8601
    end

    attribute :first_name do |object|
      object.claimant_info.dig('name', 'first')
    end

    attribute :last_name do |object|
      object.claimant_info.dig('name', 'last')
    end

    attribute :form_type, &:form_id

    attribute :packet do |object|
      object.persistent_attachments.size > 1
    end

    attribute :confirmation_number, &:guid

    attribute :vbms_status do |object|
      STATUSES[object.latest_lighthouse_submission&.latest_status]
    end

    attribute :vbms_received_date do |object|
      if STATUSES[object.latest_lighthouse_submission&.latest_status] == 'received'
        latest_lighthouse_submission(object).updated_at.to_date.iso8601
      end
    end
  end
end
