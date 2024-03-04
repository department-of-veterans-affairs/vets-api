# frozen_string_literal: true

class LighthouseDocumentUpload < ApplicationRecord
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

  # Veteran Uploads must reference a FormAttachment record as that is where we store a Veteran-submitted file's
  # metadata, including S3 URL
  validates :form_attachment, presence: true, if: :veteran_upload?

  aasm do
    after_all_transitions :log_status_change

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
      # We allow transitioning from pending_vbms_submission to failed_bgs_submission, in case we missed the event
      # where Lighthouse completed an upload to VBMS successfully before the BGS submission subsequently failed
      transitions from: %i[pending_bgs_submission pending_vbms_submission], to: :failed_bgs_submission, guard: :error_message_saved?
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

  # These status logs drive DataDog alert monitors
  def log_status_change(lighthouse_status_response)
    Rails.logger.info(
      {
        lighthouse_document_upload_id: id,
        form526_submission_id:,
        lighthouse_document_request_id:,
        error_message:,
        lighthouse_status_response:,
        from_state: aasm.from_state,
        to_state: aasm.to_state,
        event: aasm.current_event,
        # THis is wrong because this is a polling endpoint
        transitioned_at: Time.zone.now
      }
    )
  end
end
