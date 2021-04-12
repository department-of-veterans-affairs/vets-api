# frozen_string_literal: true

require 'json_marshal/marshaller'

module AppealsApi
  class EvidenceSubmission < ApplicationRecord
    include SetGuid

    self.ignored_columns = ["status"] # Temporary until migrations have run
    belongs_to :supportable, polymorphic: true, optional: true
    belongs_to :upload_submission,
               class_name: 'VBADocuments::UploadSubmission',
               foreign_key: 'upload_submission_id',
               dependent: :destroy
  end
end
