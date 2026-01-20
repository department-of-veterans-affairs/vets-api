# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/form1010cg_helpers/test_file_helpers'

RSpec.describe 'V0::Form1010CG::Attachments', type: :request do
  let(:endpoint) { 'http://localhost:3000/v0/form1010cg/attachments' }
  let(:headers) do
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded',
      'HTTP_X_KEY_INFLECTION' => 'camel'
    }
  end
  let(:vcr_options) do
    {
      record: :none,
      allow_unused_http_interactions: false,
      match_requests_on: %i[method host body]
    }
  end

  after do
    Form1010cg::Attachment.delete_all
  end

  def make_upload_request_with(file_fixture_path, content_type)
    request_options = {
      headers:,
      params: {
        attachment: {
          file_data: Form1010cgHelpers::TestFileHelpers.create_test_uploaded_file(file_fixture_path, content_type)
        }
      }
    }

    post(endpoint, **request_options)
  end

  describe 'POST /v0/form1010cg/attachments' do
    after do
      Form1010cg::Attachment.delete_all
    end

    context 'with JPG' do
      let(:form_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
      # Cache ID from VCR cassette - must match for S3 URL consistency
      let(:carrierwave_cache_id) { '1619206365-340201329057824-0002-6154' }

      before do
        # Stub CarrierWave cache_id to match VCR cassette URLs
        allow(CarrierWave).to receive(:generate_cache_id).and_return(carrierwave_cache_id)
        expect(SecureRandom).to receive(:uuid).and_call_original
        expect(SecureRandom).to receive(:uuid).and_return(form_attachment_guid) # when FormAttachment is initalized
        allow(SecureRandom).to receive(:uuid).and_call_original # Allow method to be called later in the req stack
      end

      it 'accepts a file upload' do
        VCR.use_cassette "s3/object/put/#{form_attachment_guid}/doctors-note.jpg", vcr_options do
          make_upload_request_with('doctors-note.jpg', 'image/jpg')

          expect(response).to have_http_status(:ok)

          res_body = JSON.parse(response.body)

          expect(res_body['data']).to be_present
          expect(res_body['data']['type']).to eq 'form1010cg_attachments'
          expect(res_body['data']['id'].to_i).to be > 0
          expect(res_body['data']['attributes']['guid']).to eq form_attachment_guid
        end
      end
    end

    context 'with PDF' do
      let(:form_attachment_guid) { '834d9f51-d0c7-4dc2-9f2e-9b722db98069' }
      # Cache ID from VCR cassette - must match for S3 URL consistency
      let(:carrierwave_cache_id) { '1619206361-354509863784495-0001-7383' }

      before do
        # Stub CarrierWave cache_id to match VCR cassette URLs
        allow(CarrierWave).to receive(:generate_cache_id).and_return(carrierwave_cache_id)
        expect(SecureRandom).to receive(:uuid).and_call_original
        expect(SecureRandom).to receive(:uuid).and_return(form_attachment_guid) # when FormAttachment is initalized
        allow(SecureRandom).to receive(:uuid).and_call_original # Allow method to be called later in the req stack
      end

      it 'accepts a file upload' do
        VCR.use_cassette "s3/object/put/#{form_attachment_guid}/doctors-note.pdf", vcr_options do
          make_upload_request_with('doctors-note.pdf', 'application/pdf')

          expect(response).to have_http_status(:ok)

          res_body = JSON.parse(response.body)

          expect(res_body['data']).to be_present
          expect(res_body['data']['type']).to eq 'form1010cg_attachments'
          expect(res_body['data']['id'].to_i).to be > 0
          expect(res_body['data']['attributes']['guid']).to eq form_attachment_guid
        end
      end
    end
  end
end
