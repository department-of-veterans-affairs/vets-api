# frozen_string_literal: true

module SupplementalDocumentUploadProvider
  STATSD_SUCCESS_METRIC = 'success'
  STATSD_RETRIED_METRIC = 'retried'
  STATSD_FAILED_METRIC = 'failed'

  def self.raise_not_implemented_error
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end

  def self.generate_upload_document(_file_name, _document_type)
    raise_not_implemented_error
  end

  def self.validate_upload_document(_document)
    raise_not_implemented_error
  end

  def self.submit_upload_document(_document, _file_body)
    raise_not_implemented_error
  end

  def self.log_upload_success(_uploading_class_prefix)
    raise_not_implemented_error
  end

  def self.log_upload_failure(_uploading_class_prefix, _error_class, _error_message)
    raise_not_implemented_error
  end
end
