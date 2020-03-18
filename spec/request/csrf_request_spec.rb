# frozen_string_literal: true

# This file is for exercising routes that should require CSRF protection.
# It is very much a WIP

require 'rails_helper'

RSpec.describe 'CSRF scenarios', type: :request do
  # ActionController::Base.allow_forgery_protection = false in the 'test' environment
  # We explicity enable it for this spec
  before(:all) do
    @original_val = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  after(:all) do
    ActionController::Base.allow_forgery_protection = @original_val
  end

  before do
    # innocuous route chosen for setting the CSRF token in the cookie
    get(v0_maintenance_windows_path)
    @token = response.cookies['X-CSRF-Token']
  end

  # POST attachment
  describe 'HcaAttachmentsController#create' do
    context 'with a CSRF token' do
      it 'uploads an hca attachment' do
        post(v0_hca_attachments_path,
             params: { hca_attachment: { file_data: fixture_file_upload('pdf_fill/extras.pdf') } },
             headers: { 'X-CSRF-Token' => @token })

        expect(JSON.parse(response.body)['data']['attributes']['guid']).to eq HcaAttachment.last.guid
      end
    end

    context 'without a CSRF token' do
      it 'logs the info to sentry' do
        expect(Raven).to receive(:capture_message).once
        with_settings(Settings.sentry, dsn: 'truthy') do
          post(v0_hca_attachments_path,
               params: { hca_attachment: { file_data: fixture_file_upload('pdf_fill/extras.pdf') } })
        end
      end

      it 'returns an error' do
        skip 'this should be live test when CSRF is enforced'
        # post(v0_hca_attachments_path,
        #   params: { hca_attachment: { file_data: fixture_file_upload('pdf_fill/extras.pdf') } }
        # )
        # expect(response.status).to eq 500
      end
    end
  end

  # SAML callback
  describe 'POST SAML callback' do
    context 'without a CSRF token' do
      it 'does not raise an error' do
        expect(Raven).not_to receive(:capture_message).with('Request susceptible to CSRF', level: 'info')
        with_settings(Settings.sentry, dsn: 'truthy') do
          post(auth_saml_callback_path)
        end
        # expect(response.body).not_to match(/ActionController::InvalidAuthenticityToken/)
      end

      it 'does not raise an error for v1' do
        expect(Raven).not_to receive(:capture_message).with('Request susceptible to CSRF', level: 'info')
        with_settings(Settings.sentry, dsn: 'truthy') do
          post(v1_sessions_callback_path)
        end
        # expect(response.body).not_to match(/ActionController::InvalidAuthenticityToken/)
      end
    end
  end
end
