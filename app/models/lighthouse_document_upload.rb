# frozen_string_literal: true

class LighthouseDocumentUpload < ApplicationRecord
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
  validates :form_attachment, presence: true, if: :veteran_upload?

  private

  def veteran_upload?
    document_type == VETERAN_UPLOAD_DOCUMENT_TYPE
  end
end
