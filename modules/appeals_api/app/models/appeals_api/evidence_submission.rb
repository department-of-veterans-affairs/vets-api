# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class EvidenceSubmission < ApplicationRecord
    include SetGuid
    self.ignored_columns = ['status'] # Temporary until migrations have run
    belongs_to :supportable, polymorphic: true
    belongs_to :upload_submission,
               class_name: 'VBADocuments::UploadSubmission',
               dependent: :destroy

    STATUSES = VBADocuments::UploadSubmission::ALL_STATUSES
    delegate :status, to: :upload_submission

    scope :errored, lambda {
      joins(:upload_submission).where('vba_documents_upload_submissions.status' => 'error')
    }
  end
end
