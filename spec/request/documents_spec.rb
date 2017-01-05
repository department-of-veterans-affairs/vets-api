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
  let(:document_type) { 'L023' }
  let!(:claim) do
    FactoryGirl.create(:evss_claim, id: 1, evss_id: 189_625,
                                          user_uuid: user.uuid, data: {})
  end
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  it 'should upload a file' do
    params = { file: file, tracked_item_id: tracked_item_id, document_type: document_type }
    expect do
      post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
    end.to change(EVSSClaim::DocumentUpload.jobs, :size).by(1)
    expect(response.status).to eq(202)
    expect(JSON.parse(response.body)['job_id']).to eq(EVSSClaim::DocumentUpload.jobs.first['jid'])
  end

  it 'should reject files with invalid document_types' do
    params = { file: file, tracked_item_id: tracked_item_id, document_type: 'invalid type' }
    post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
    expect(response.status).to eq(422)
  end

  it 'should reject requests without a tracked_item_id' do
    params = { file: file, tracked_item_id: '', document_type: document_type }
    post '/v0/evss_claims/189625/documents', params, 'Authorization' => "Token token=#{session.token}"
    expect(response.status).to eq(422)
  end
end
