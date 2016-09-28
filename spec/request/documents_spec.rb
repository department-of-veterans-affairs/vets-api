# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Documents management', type: :request do
  let(:file) do
    fixture_file_upload(
      "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf",
      'application/pdf'
    )
  end
  let(:tracked_item) { 33 }
  let(:claim_id) { 189_625 }

  it 'should upload a file' do
    ActiveJob::Base.queue_adapter = :test
    params = { file: file, tracked_item: tracked_item }
    expect do
      post "/v0/disability_claims/#{claim_id}/documents", params
    end.to have_enqueued_job(DisabilityClaim::DocumentUpload)
    expect(response).to be_success
    expect(response.body).to be_empty
  end
end
