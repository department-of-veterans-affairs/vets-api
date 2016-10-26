# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaim::DocumentUpload, type: :job do
  let(:client_stub) { instance_double('EVSS::DocumentsService') }
  let(:uploader_stub) { instance_double('DisabilityClaimDocumentUploader') }
  let(:user) { FactoryGirl.create(:mvi_user) }
  let(:claim_id) { 189_625 }
  let(:tracked_item_id) { 33 }
  let(:filename) { 'doctors-note.pdf' }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

  it 'retrieves the file and uploads to EVSS' do
    allow(DisabilityClaimDocumentUploader).to receive(:new) { uploader_stub }
    allow(EVSS::DocumentsService).to receive(:new) { client_stub }
    file = File.read("#{::Rails.root}/spec/fixtures/files/#{filename}")
    allow(uploader_stub).to receive(:retrieve_from_store!).with(filename) { file }
    allow(uploader_stub).to receive(:read) { file }
    expect(uploader_stub).to receive(:remove!).once
    expect(client_stub).to receive(:upload).with(filename, file, claim_id, tracked_item_id)
    described_class.new.perform(filename, auth_headers, user.uuid, 189_625, 33)
  end
end
