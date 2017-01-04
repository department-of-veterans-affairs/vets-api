# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

RSpec.describe DisabilityClaim::DocumentUpload, type: :job do
  let(:client_stub) { instance_double('EVSS::DocumentsService') }
  let(:uploader_stub) { instance_double('DisabilityClaimDocumentUploader') }
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:filename) { 'doctors-note.pdf' }
  let(:document_data) do
    DisabilityClaimDocument.new(
      evss_claim_id: 189_625,
      file_name: filename,
      tracked_item_id: 33,
      document_type: 'L023'
    )
  end
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

  it 'retrieves the file and uploads to EVSS' do
    allow(DisabilityClaimDocumentUploader).to receive(:new) { uploader_stub }
    allow(EVSS::DocumentsService).to receive(:new) { client_stub }
    file = File.read("#{::Rails.root}/spec/fixtures/files/#{filename}")
    allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
    allow(uploader_stub).to receive(:read) { file }
    expect(uploader_stub).to receive(:remove!).once
    expect(client_stub).to receive(:upload).with(file, document_data)
    described_class.new.perform(auth_headers, user.uuid, document_data.to_h)
  end
end
