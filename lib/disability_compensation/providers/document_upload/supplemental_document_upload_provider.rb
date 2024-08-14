# frozen_string_literal: true

module SupplementalDocumentUploadProvider
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

  protected

  def handle_submission_success(statsd_prefix)
    raise_not_implemented_error
  end

  def handle_submission_retryable_error(statsd_prefix, error)
    raise_not_implemented_error
  end

  def handle_submission_retry_exhaustion(statsd_prefix)
    raise_not_implemented_error
  end
end
