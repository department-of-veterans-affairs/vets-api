# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::ClaimDocuments', type: :request do
  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
    allow(Common::VirusScan).to receive(:scan).and_return(true)
    allow_any_instance_of(Common::VirusScan).to receive(:scan).and_return(true)
  end

  context 'with a valid file' do
    let(:file) do
      fixture_file_upload('doctors-note.pdf')
    end

    it 'uploads a file' do
      VCR.use_cassette('uploads/validate_document') do
        params = { file:, form_id: '21P-527EZ' }
        expect do
          post('/v0/claim_documents', params:)
        end.to change(PersistentAttachment, :count).by(1)
        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
        expect(PersistentAttachment.last).to be_a(PersistentAttachments::PensionBurial)
      end
    end

    it 'uploads a file to the alternate route' do
      VCR.use_cassette('uploads/validate_document') do
        params = { file:, form_id: '21P-527EZ' }
        expect do
          post('/v0/claim_attachments', params:)
        end.to change(PersistentAttachment, :count).by(1)
        expect(response).to have_http_status(:ok)
        resp = JSON.parse(response.body)
        expect(resp['data']['attributes'].keys.sort).to eq(%w[confirmation_code name size])
        expect(PersistentAttachment.last).to be_a(PersistentAttachments::PensionBurial)
      end
    end

    it 'logs a successful upload' do
      VCR.use_cassette('uploads/validate_document') do
        expect(Rails.logger).to receive(:info).with('Creating PersistentAttachment FormID=21P-527EZ', instance_of(Hash))
        expect(Rails.logger).to receive(:info).with(
          /^Success creating PersistentAttachment FormID=21P-527EZ AttachmentID=\d+/, instance_of(Hash)
        )
        expect(Rails.logger).not_to receive(:error).with(
          'Error creating PersistentAttachment FormID=21P-527EZ AttachmentID= Common::Exceptions::ValidationErrors'
        )

        params = { file:, form_id: '21P-527EZ' }
        expect do
          post('/v0/claim_documents', params:)
        end.to change(PersistentAttachment, :count).by(1)
      end
    end
  end

  context 'with an invalid file' do
    let(:file) { fixture_file_upload('empty-file.jpg') }

    it 'does not upload the file' do
      VCR.use_cassette('uploads/validate_document') do
        params = { file:, form_id: '21P-527EZ' }
        expect do
          post('/v0/claim_attachments', params:)
        end.not_to change(PersistentAttachment, :count)
        expect(response).to have_http_status(:unprocessable_entity)
        resp = JSON.parse(response.body)
        expect(resp['errors'][0]['detail']).to eq('File size must not be less than 1.0 KB')
      end
    end

    it 'logs the error' do
      VCR.use_cassette('uploads/validate_document') do
        expect(Rails.logger).to receive(:info).with('Creating PersistentAttachment FormID=21P-527EZ',
                                                    hash_including(statsd: 'api.claim_documents.attempt'))
        expect(Rails.logger).not_to receive(:info).with(
          /^Success creating PersistentAttachment FormID=21P-527EZ AttachmentID=\d+/
        )
        expect(Rails.logger).to receive(:error).with(
          'Input error creating PersistentAttachment ' \
          'FormID=21P-527EZ AttachmentID= Common::Exceptions::UnprocessableEntity',
          instance_of(Hash)
        )

        params = { file:, form_id: '21P-527EZ' }
        post('/v0/claim_attachments', params:)
      end
    end
  end

  context 'with a password protected file' do
    let(:file) do
      fixture_file_upload('password_is_test.pdf')
    end

    it 'does not raise an error when password is correct' do
      VCR.use_cassette('uploads/validate_document') do
        params = { file:, form_id: '26-1880', password: 'test' }
        post('/v0/claim_attachments', params:)
        expect(response).to have_http_status(:ok)
      end
    end

    it 'raises an error when password is incorrect' do
      params = { file:, form_id: '26-1880', password: 'bad_password' }
      post('/v0/claim_attachments', params:)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
