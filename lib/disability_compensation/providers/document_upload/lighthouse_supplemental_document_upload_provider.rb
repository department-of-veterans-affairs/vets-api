# frozen_string_literal: true

require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'

class LighthouseSupplementalDocumentUploadProvider
  include SupplementalDocumentUploadProvider

  # @param form526_submission [Form526Submission]
  # @param file_body [String]
  def initialize(form526_submission, file_body)
    @form526_submission = form526_submission
    @file_body = file_body
  end

  def generate_upload_document(file_name, document_type)
    # TODO: implement in https://github.com/department-of-veterans-affairs/va.gov-team/issues/90059
  end

  def validate_upload_document(lighthouse_document)
    # TODO: implement in https://github.com/department-of-veterans-affairs/va.gov-team/issues/90059
  end

  def submit_upload_document(lighthouse_document)
    # TODO: implement in https://github.com/department-of-veterans-affairs/va.gov-team/issues/90059
  end
end
