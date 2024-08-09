# frozen_string_literal: true

module SupplementalDocumentUploadProvider
  def self.generate_upload_document(file_name, document_type)
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end

  def self.validate_upload_document(lighthouse_document)
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end

  def self.submit_upload_document(lighthouse_document)
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
