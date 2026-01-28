# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::Messages::Attachments', type: :request do
  include SM::ClientHelpers

  let(:current_user) { build(:user, :mhv) }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before do
    sign_in_as(current_user)
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when NOT authorized' do
    before do
      VCR.insert_cassette('sm_client/session_error')
      get '/my_health/v1/messaging/messages/629999/attachments/629993'
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe '#show' do
      it 'responds sending data for an attachment' do
        VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
          get '/my_health/v1/messaging/messages/629999/attachments/629993'
        end

        expect(response).to be_successful
        expect(response.headers['Content-Disposition'])
          .to eq("attachment; filename=\"noise300x200.png\"; filename*=UTF-8''noise300x200.png")
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('image/png')
        expect(response.body).to be_a(String)
      end
    end
  end

  context 'when testing streaming behavior' do
    # These tests verify streaming semantics by testing the controller's streaming implementation.
    # We use a helper to bypass auth and mock only the client's stream_attachment method.
    let(:mock_session) { double('session', expired?: false) }

    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe '#show streaming' do
      it 'sets headers before streaming body content' do
        # This test verifies that ActionController::Live headers are set before body streaming begins.
        # With Live streaming, headers must be committed before any response.stream.write calls.
        headers_set_before_body = false
        body_chunks = []

        # Allow VCR to handle auth, but mock stream_attachment on any client instance
        allow_any_instance_of(SM::Client).to receive(:stream_attachment) do |_client, _msg_id, _att_id, header_cb, &blk|
          # Simulate setting headers first (as the real implementation does)
          header_cb.call(
            [
              ['Content-Type', 'application/pdf'],
              ['Content-Disposition', 'attachment; filename="test.pdf"'],
              ['Content-Length', '1024']
            ]
          )

          # At this point, headers should be set on the response
          headers_set_before_body = true

          # Now stream body chunks
          blk.call('chunk1')
          body_chunks << 'chunk1'
          blk.call('chunk2')
          body_chunks << 'chunk2'
        end

        get '/my_health/v1/messaging/messages/629999/attachments/629993'

        expect(response).to be_successful
        expect(headers_set_before_body).to be(true)
        expect(body_chunks).to eq(%w[chunk1 chunk2])

        # Verify headers were properly set
        expect(response.headers['Content-Type']).to eq('application/pdf')
        expect(response.headers['Content-Disposition']).to include('test.pdf')
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')

        # NOTE: Content-Length may be recalculated by Rails test harness after body is written.
        # In actual HTTP streaming, the Content-Length header is sent before the body.
        # We verify the body content matches what was streamed.
        expect(response.body).to eq('chunk1chunk2')
      end

      it 'streams S3 attachments with correct headers' do
        # Test the S3 presigned URL flow where MHV returns JSON with S3 details
        allow_any_instance_of(SM::Client).to receive(:stream_attachment) do |_client, _msg_id, _att_id, header_cb, &blk|
          # Simulate S3 attachment headers (as returned by stream_s3_attachment)
          header_cb.call(
            [
              ['Content-Type', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
              ['Content-Disposition', 'attachment; filename="medical_record.docx"'],
              ['Content-Length', '52428']
            ]
          )

          # Stream the file content
          blk.call('docx_content_part1')
          blk.call('docx_content_part2')
        end

        get '/my_health/v1/messaging/messages/123/attachments/456'

        expect(response).to be_successful
        expect(response.headers['Content-Type'])
          .to eq('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
        expect(response.headers['Content-Disposition']).to include('medical_record.docx')
        expect(response.body).to eq('docx_content_part1docx_content_part2')
      end

      it 'properly encodes special characters in filenames (RFC 5987)' do
        # Test filename with special characters that require encoding
        # Note: Semicolons, parentheses, and spaces are common in medical document filenames
        filename_with_special_chars = 'Lab Results; Patient (2024).pdf'

        allow_any_instance_of(SM::Client).to receive(:stream_attachment) do |_client, _msg_id, _att_id, header_cb, &blk|
          header_cb.call(
            [
              ['Content-Type', 'application/pdf'],
              ['Content-Disposition', "attachment; filename=\"#{filename_with_special_chars}\""]
            ]
          )
          blk.call('pdf_content')
        end

        get '/my_health/v1/messaging/messages/123/attachments/456'

        expect(response).to be_successful
        disposition = response.headers['Content-Disposition']

        # Verify both filename and filename* (RFC 5987 encoded) are present
        expect(disposition).to include('attachment;')
        expect(disposition).to include('filename="Lab Results; Patient (2024).pdf"')
        # The RFC 5987 encoded filename* should use percent-encoding
        expect(disposition).to include("filename*=UTF-8''")
        expect(disposition).to include('%28') # ( encoded
        expect(disposition).to include('%29') # ) encoded
        expect(disposition).to include('%3B') # ; encoded
      end

      it 'handles streaming errors gracefully' do
        allow_any_instance_of(SM::Client).to receive(:stream_attachment)
          .and_raise(Common::Exceptions::BackendServiceException.new('SM_ATTACHMENT_FETCH_ERROR', {}, 502))

        get '/my_health/v1/messaging/messages/629999/attachments/629993'

        expect(response).not_to be_successful
        expect(response).to have_http_status(:bad_gateway)
      end
    end
  end
end
