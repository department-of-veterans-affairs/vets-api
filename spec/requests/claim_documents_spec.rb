# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Claim Document Attachment', type: :request do
  let(:file) do
    fixture_file_upload('doctors-note.pdf')
  end

  before do
    allow(Common::VirusScan).to receive(:scan).and_return(true)
    allow_any_instance_of(Common::VirusScan).to receive(:scan).and_return(true)
  end

  it 'uploads a file' do
    params = { file: file, form_id: '21P-527EZ' }
    expect do
      post '/v0/claim_documents', params: params
    end.to change(PersistentAttachment, :count).by(1)
    expect(response.status).to eq(200)
    resp = JSON.parse(response.body)
    expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
    expect(PersistentAttachment.last).to be_a(PersistentAttachments::PensionBurial)
  end
end
