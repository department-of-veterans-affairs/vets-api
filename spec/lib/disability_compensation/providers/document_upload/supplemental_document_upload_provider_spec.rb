# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/providers/document_upload/supplemental_document_upload_provider'

RSpec.describe SupplementalDocumentUploadProvider do
  it 'raises an error if the generate_upload_document method is not implemented' do
    expect do
      subject.generate_upload_document(Faker::File.file_name, 'L023')
    end.to raise_error NotImplementedError
  end

  it 'raises an error if the validate_upload_document method is not implemented' do
    expect do
      subject.validate_upload_document(LighthouseDocument.new)
    end.to raise_error NotImplementedError
  end

  it 'raises an error if the submit_upload_document method is not implemented' do
    expect do
      subject.submit_upload_document(LighthouseDocument.new)
    end.to raise_error NotImplementedError
  end

  it 'raises an error if the log_upload_success method is not implemented' do
    expect do
      subject.log_upload_success('my_upload_job_prefix')
    end.to raise_error NotImplementedError
  end

  it 'raises an error if the log_upload_error_retry method is not implemented' do
    expect do
      subject.log_upload_error_retry('my_upload_job_prefix')
    end.to raise_error NotImplementedError
  end

  it 'raises an error if the log_upload_failure method is not implemented' do
    expect do
      subject.log_upload_failure('my_upload_job_prefix', StandardError.new)
    end.to raise_error NotImplementedError
  end
end
