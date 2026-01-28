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
      get '/my_health/v1/messaging/messages/629999/attachments/629993'
    end

    after do
      VCR.eject_cassette
    end

    describe '#show' do
      before do
        # Default: feature flag disabled for legacy tests
        allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_stream_via_revproxy, anything).and_return(false)
      end

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

      context 'with X-Accel-Redirect feature flag enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_stream_via_revproxy,
                                                    anything).and_return(true)
        end

        context 'when attachment is S3-backed' do
          it 'responds with X-Accel-Redirect headers and empty body' do
            s3_url = 'https://my-bucket.s3.us-gov-west-1.amazonaws.com/path/to/file.pdf?presigned=true'
            attachment_info = {
              s3_url:,
              mime_type: 'application/pdf',
              filename: 'test-document.pdf',
              body: nil
            }

            # Stub the unified method to return S3 info
            allow_any_instance_of(SM::Client).to receive(:get_attachment_info)
              .with('629999', '629993')
              .and_return(attachment_info)

            get '/my_health/v1/messaging/messages/629999/attachments/629993'

            expect(response).to have_http_status(:ok)
            expect(response.headers['X-Accel-Redirect']).to include('/internal-s3-proxy/')
            expect(response.headers['X-Accel-Redirect']).to include(CGI.escape(s3_url))
            expect(response.headers['Content-Type']).to eq('application/pdf')
            expect(response.headers['Content-Disposition']).to eq('attachment; filename="test-document.pdf"')
            expect(response.headers['Cache-Control']).to include('private')
            expect(response.headers['Cache-Control']).to include('no-store')
            expect(response.body).to be_empty
          end

          it 'sanitizes malicious filenames' do
            s3_url = 'https://my-bucket.s3.us-gov-west-1.amazonaws.com/file.pdf'
            attachment_info = {
              s3_url:,
              mime_type: 'application/pdf',
              filename: "test\r\nX-Evil-Header: injected\r\n.pdf",
              body: nil
            }

            allow_any_instance_of(SM::Client).to receive(:get_attachment_info)
              .with('629999', '629993')
              .and_return(attachment_info)

            get '/my_health/v1/messaging/messages/629999/attachments/629993'

            expect(response).to have_http_status(:ok)
            # Filename should be sanitized - \r\n chars replaced with underscores
            expect(response.headers['Content-Disposition']).to match(/filename="test__X-Evil-Header_ injected__.pdf"/)
            expect(response.headers['Content-Disposition']).not_to include("\r")
            expect(response.headers['Content-Disposition']).not_to include("\n")
          end
        end

        context 'when get_attachment_info fails' do
          it 'falls back to legacy approach' do
            # First call to get_attachment_info fails, triggering fallback
            allow_any_instance_of(SM::Client).to receive(:get_attachment_info)
              .and_raise(StandardError, 'API error')

            # Fallback uses get_attachment directly (which wraps get_attachment_info),
            # so we stub it separately to return valid data for the fallback path
            allow_any_instance_of(SM::Client).to receive(:get_attachment)
              .and_return({ body: 'binary file content', filename: 'test.pdf' })

            VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
              get '/my_health/v1/messaging/messages/629999/attachments/629993'
            end

            expect(response).to be_successful
            expect(response.headers['X-Accel-Redirect']).to be_nil
            expect(response.body).to be_a(String)
            expect(response.body.bytesize).to be_positive
          end
        end

        context 'when attachment is not S3-backed' do
          it 'uses send_data with body from single request' do
            # Non-S3 attachment returns body directly, no second request needed
            attachment_info = {
              s3_url: nil,
              mime_type: nil,
              filename: 'noise300x200.png',
              body: 'binary file content'
            }

            allow_any_instance_of(SM::Client).to receive(:get_attachment_info)
              .with('629999', '629993')
              .and_return(attachment_info)

            get '/my_health/v1/messaging/messages/629999/attachments/629993'

            expect(response).to be_successful
            expect(response.headers['X-Accel-Redirect']).to be_nil
            expect(response.body).to eq('binary file content')
          end
        end
      end

      context 'with X-Accel-Redirect feature flag disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:mhv_secure_messaging_stream_via_revproxy,
                                                    anything).and_return(false)
        end

        it 'uses legacy send_data approach' do
          VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
            get '/my_health/v1/messaging/messages/629999/attachments/629993'
          end

          expect(response).to be_successful
          expect(response.headers['X-Accel-Redirect']).to be_nil
          expect(response.body).to be_a(String)
          expect(response.body.bytesize).to be_positive
        end
      end
    end
  end
end
