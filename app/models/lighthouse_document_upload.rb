# frozen_string_literal: true

class LighthouseDocumentUpload < ApplicationRecord
  include AASM

  VETERAN_UPLOAD_DOCUMENT_TYPE = 'Veteran Upload'
  VALID_DOCUMENT_TYPES = [
    'BDD Instructions',
    'Form 0781',
    'Form 0781a',
    VETERAN_UPLOAD_DOCUMENT_TYPE
  ].freeze

  belongs_to :form526_submission
  belongs_to :form_attachment, optional: true

  validates :lighthouse_document_request_id, presence: true
  validates :document_type, presence: true, inclusion: { in: VALID_DOCUMENT_TYPES }

  # Veteran Uploads must reference a FormAttachment record as that is where we store a Veteran-submitted file's
  # metadata, including S3 URL
  validates :form_attachment, presence: true, if: :veteran_upload?

  aasm do
    state :pending_vbms_submission, initial: true
    state :failed_vbms_submission, :pending_bgs_submission, :failed_bgs_submission, :complete

    event :vbms_submission_complete do
      transitions from: :pending_vbms_submission, to: :pending_bgs_submission
    end

    event :vbms_submission_failed do
      transitions from: :pending_vbms_submission, to: :failed_vbms_submission, guard: :error_message_saved?
    end

    event :bgs_submission_complete do
      transitions from: :pending_bgs_submission, to: :complete, guard: :lighthouse_end_time_saved?
    end

    event :bgs_submission_failed do
      transitions from: :pending_bgs_submission, to: :failed_bgs_submission, guard: :error_message_saved?
    end
  end

  private

  def veteran_upload?
    document_type == VETERAN_UPLOAD_DOCUMENT_TYPE
  end

  def lighthouse_end_time_saved?
    lighthouse_processing_ended_at != nil
  end

  def error_message_saved?
    error_message != nil
  end
end
