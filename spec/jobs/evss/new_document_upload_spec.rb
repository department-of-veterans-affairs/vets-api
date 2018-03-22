# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::NewDocumentUpload, type: :job do
  let(:client_stub) { instance_double('EVSS::Documents::Service') }
  let(:uploader_stub) { instance_double('EVSSClaimDocumentUploader') }
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:filename) { 'doctors-note.pdf' }
  let(:document_data) do
    EVSSClaimDocument.new(
      evss_claim_id: 189_625,
      file_name: filename,
      tracked_item_id: 33,
      document_type: 'L023'
    )
  end

  it 'retrieves the file and uploads to EVSS' do
    allow(EVSSClaimDocumentUploader).to receive(:new) { uploader_stub }
    allow(EVSS::Documents::Service).to receive(:new) { client_stub }
    file = File.read("#{::Rails.root}/spec/fixtures/files/#{filename}")
    allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
    allow(uploader_stub).to receive(:read_for_upload) { file }
    expect(uploader_stub).to receive(:remove!).once
    expect(client_stub).to receive(:upload).with(file, document_data)
    described_class.new.perform(user.uuid, document_data.to_serializable_hash)
  end
end
