# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Claim Document Attachment', type: :request do
  let(:file) do
    fixture_file_upload('doctors-note.pdf')
  end

  it 'uploads a file' do
    allow(ClamScan::Client).to receive(:scan)
      .and_return(instance_double('ClamScan::Response', safe?: true))
    params = { file:, form_id: '21P-527EZ' }
    expect do
      post('/v0/claim_documents', params:)
    end.to change(PersistentAttachment, :count).by(1)
    expect(response.status).to eq(200)
    resp = JSON.parse(response.body)
    expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
    expect(PersistentAttachment.last).to be_a(PersistentAttachments::PensionBurial)
  end
end
