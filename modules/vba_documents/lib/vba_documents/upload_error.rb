# frozen_string_literal: true

module VBADocuments
  class UploadError < CentralMail::UploadError
    STATSD_UPLOAD_FAIL_KEY = 'api.vba.document_upload.fail'
  end
end
