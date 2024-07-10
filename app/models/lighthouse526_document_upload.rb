# frozen_string_literal: true

class Lighthouse526DocumentUpload < ApplicationRecord
  include AASM

  VETERAN_UPLOAD_DOCUMENT_TYPE = 'Veteran Upload'
  BDD_INSTRUCTIONS_DOCUMENT_TYPE = 'BDD Instructions'
  FORM_0781_DOCUMENT_TYPE = 'Form 0781'
  FORM_0781A_DOCUMENT_TYPE = 'Form 0781a'

  VALID_DOCUMENT_TYPES = [
    BDD_INSTRUCTIONS_DOCUMENT_TYPE,
    FORM_0781_DOCUMENT_TYPE,
    FORM_0781A_DOCUMENT_TYPE,
    VETERAN_UPLOAD_DOCUMENT_TYPE
  ].freeze

  belongs_to :form526_submission
  belongs_to :form_attachment, optional: true

  validates :lighthouse_document_request_id, presence: true
  validates :document_type, presence: true, inclusion: { in: VALID_DOCUMENT_TYPES }

  # Veteran Uploads must reference a FormAttachment record, where a Veteran-submitted file is stored
  validates :form_attachment, presence: true, if: :veteran_upload?

  aasm do
    state :pending, initial: true
    state :completed, :failed

    event :complete do
      transitions from: :pending, to: :completed, guard: :end_time_saved?
    end

    event :fail do
      transitions from: :pending, to: :failed, guard: %i[end_time_saved? error_message_saved?]
    end
  end

  private

  def veteran_upload?
    document_type == VETERAN_UPLOAD_DOCUMENT_TYPE
  end

  def end_time_saved?
    lighthouse_processing_ended_at != nil
  end

  def error_message_saved?
    error_message != nil
  end
end
