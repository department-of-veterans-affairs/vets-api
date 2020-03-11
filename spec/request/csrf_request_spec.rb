# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CSRF scenarios', type: :request do
  before do 
    get(v0_maintenance_windows_path)
    @token = response.cookies['X-CSRF-Token']
  end

  # POST attachment
  describe 'HcaAttachmentsController#create' do
    context 'with a CSRF token' do
      it 'uploads an hca attachment' do
        post(v0_hca_attachments_path,
          params: { hca_attachment: { file_data: fixture_file_upload('pdf_fill/extras.pdf') } },
          headers: { 'X-CSRF-Token' => @token }
        )

        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HcaAttachment.last.guid
      end
    end
    context 'without a CSRF token' do
      it 'returns an error' do
        post(v0_hca_attachments_path,
          params: { hca_attachment: { file_data: fixture_file_upload('pdf_fill/extras.pdf') } }
        )
        expect(response.status).to eq 500
      end
    end
  end

  # SAML callback
  describe 'POST SAML callback' do
    context 'without a CSRF token' do
      it 'does not raise an error' do
        post(auth_saml_callback_path)
        expect(response.body).not_to match(/ActionController::InvalidAuthenticityToken/)
      end
    end
  end

  # TODO:
  # Lighthouse API endpoints
  # Check routes.rb for other `POST` routes
  

end