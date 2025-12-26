# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class EvidenceSubmission < ApplicationRecord
    include SetGuid
    belongs_to :supportable, polymorphic: true
    belongs_to :upload_submission,
               class_name: 'VBADocuments::UploadSubmission',
               dependent: :destroy

    STATUSES = VBADocuments::UploadSubmission::ALL_STATUSES

    delegate :in_final_status?, to: :upload_submission
    delegate :status, to: :upload_submission
    delegate :code, to: :upload_submission
    delegate :detail, to: :upload_submission

    scope :errored, lambda {
      joins(:upload_submission).where(upload_submission: { status: 'error' })
    }

    scope :uploaded, lambda {
      joins(:upload_submission).where(upload_submission: { status: 'uploaded' })
    }

    def submit_to_central_mail!
      if status == 'uploaded'
        VBADocuments::UploadProcessor.perform_async(upload_submission.guid, caller: self.class.name)
      end
    end
  end
end
