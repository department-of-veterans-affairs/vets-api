# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Documents management', type: :request do
  let(:file) do
    fixture_file_upload(
      "#{::Rails.root}/spec/fixtures/files/doctors-note.pdf",
      'application/pdf'
    )
  end
  let(:tracked_item_id) { 33 }
  let(:claim_id) { 189_625 }
  let(:document_type) { 'L023' }
  let!(:claim) do
    FactoryGirl.create(:disability_claim, id: 189_625, evss_id: 189_625,
                                          user_uuid: User.sample_claimant.uuid, data: {})
  end

  it 'should upload a file' do
    params = { file: file, tracked_item_id: tracked_item_id, document_type: document_type }
    expect do
      post "/v0/disability_claims/#{claim_id}/documents", params
    end.to change(DisabilityClaim::DocumentUpload.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(JSON.parse(response.body)['job_id']).to eq(DisabilityClaim::DocumentUpload.jobs.first['jid'])
  end

  it 'should reject files with invalid document_types' do
    params = { file: file, tracked_item_id: tracked_item_id, document_type: 'invalid type' }
    post "/v0/disability_claims/#{claim_id}/documents", params
    expect(response.status).to eq(422)
  end

  it 'should reject requests without a tracked_item_id' do
    params = { file: file, tracked_item_id: '', document_type: document_type }
    post "/v0/disability_claims/#{claim_id}/documents", params
    expect(response.status).to eq(422)
  end
end
