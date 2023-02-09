# frozen_string_literal: true

require 'rails_helper'

describe VBADocuments::UploadSerializer do
  let(:upload_submission) { FactoryBot.create(:upload_submission, :status_uploaded) }
  let(:rendered_hash) { described_class.new(upload_submission).serializable_hash }

  it 'serializes the UploadSubmission properly' do
    expect(rendered_hash).to eq(
      {
        guid: upload_submission.guid,
        status: upload_submission.status,
        code: upload_submission.code,
        detail: '',
        location: nil,
        updated_at: upload_submission.updated_at,
        uploaded_pdf: upload_submission.uploaded_pdf
      }
    )
  end
end
