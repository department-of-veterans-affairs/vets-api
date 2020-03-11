# frozen_string_literal: true

# This file is for exercising routes that should require CSRF protection.
# It is very much a WIP

# TODO:
# Lighthouse API endpoints
# Check routes.rb for other `POST` routes

require 'rails_helper'

RSpec.describe 'CSRF scenarios', type: :request do

  around(:example) do |example|
    original_val = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
    ActionController::Base.allow_forgery_protection = original_val
  end

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
end
