# frozen_string_literal: true

module SupplementalDocumentUploadProvider
  STATSD_SUCCESS_METRIC = 'success'
  STATSD_RETRIED_METRIC = 'retried'
  STATSD_FAILED_METRIC = 'failed'

  def self.raise_not_implemented_error
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end

  def self.generate_upload_document(file_name, document_type)
    raise_not_implemented_error
  end

  def self.validate_upload_document(lighthouse_document)
    raise_not_implemented_error
  end

  def self.submit_upload_document(lighthouse_document)
    raise_not_implemented_error
  end

  def self.log_upload_success(uploading_class_prefix)
    raise_not_implemented_error
  end

  def self.log_upload_error_retry(uploading_class_prefix)
    raise_not_implemented_error
  end

  def self.log_upload_failure(uploading_class_prefix, error)
    raise_not_implemented_error
  end
end
