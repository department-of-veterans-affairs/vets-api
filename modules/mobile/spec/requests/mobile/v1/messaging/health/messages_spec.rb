# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V1::Messaging::Health::Messages', type: :request do
  let!(:user) { sis_user(:mhv, :api_auth, mhv_correlation_id: '123', mhv_account_type: 'Premium') }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when user does not have access' do
    let!(:user) { sis_user(:mhv, mhv_account_type: 'Free') }

    it 'returns forbidden' do
      get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when not authorized' do
    it 'responds with 403 error' do
      VCR.use_cassette('mobile/messages/session_error') do
        get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers
      end
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    let(:thread_response) do
      { 'data' =>
          [
            {
              'id' => '573059',
              'type' => 'message_thread_details',
              'attributes' => {
                'messageId' => 573_059,
                'category' => 'OTHER',
                'subject' => 'Release 16.2 - SM last login ',
                'body' => 'Provider Reply',
                'messageBody' => 'Provider Reply',
                'attachment' => false,
                'sentDate' => nil,
                'senderId' => 257_555,
                'senderName' => 'ISLAM, MOHAMMAD',
                'recipientId' => 384_939,
                'recipientName' => 'MVIONE, TEST',
                'readReceipt' => 'READ',
                'triageGroupName' => 'VA Flagship mobile applications interface 1_DAYT29',
                'proxySenderName' => nil,
                'threadId' => 2_800_585,
                'folderId' => -2,
                'draftDate' => '2023-05-16T14:55:01+00:00',
                'toDate' => nil,
                'hasAttachments' => false,
                'replyDisabled' => false
              },
              'links' => {
                'self' => 'http://www.example.com/mobile/v0/messaging/health/messages/573059'
              }
            },
            {
              'id' => '573052',
              'type' => 'message_thread_details',
              'attributes' => {
                'messageId' => 573_052,
                'category' => 'OTHER',
                'subject' => 'Release 16.2 - SM last login ',
                'body' => 'Provider Reply',
                'messageBody' => 'Provider Reply',
                'attachment' => false,
                'sentDate' => nil,
                'senderId' => 257_555,
                'senderName' => 'ISLAM, MOHAMMAD',
                'recipientId' => 384_939,
                'recipientName' => 'MVIONE, TEST',
                'readReceipt' => 'READ',
                'triageGroupName' => 'VA Flagship mobile applications interface 1_DAYT29',
                'proxySenderName' => nil,
                'threadId' => 2_800_585,
                'folderId' => -2,
                'draftDate' => '2023-05-16T14:55:01+00:00',
                'toDate' => nil,
                'hasAttachments' => false,
                'replyDisabled' => false
              },
              'links' => {
                'self' => 'http://www.example.com/mobile/v0/messaging/health/messages/573052'
              }
            },
            {
              'id' => '573041',
              'type' => 'message_thread_details',
              'attributes' => {
                'messageId' => 573_041,
                'category' => 'OTHER',
                'subject' => 'Release 16.2- SM last login ',
                'body' => 'Release 16.2- SM last login ',
                'messageBody' => 'Release 16.2- SM last login ',
                'attachment' => false,
                'sentDate' => nil,
                'senderId' => 384_939,
                'senderName' => 'MVIONE, TEST',
                'recipientId' => 345_468,
                'recipientName' => 'WORKLOAD CAPTURE_Mohammad',
                'readReceipt' => 'READ',
                'triageGroupName' => 'VA Flagship mobile applications interface 1_DAYT29',
                'proxySenderName' => nil,
                'threadId' => 2_800_585,
                'folderId' => -2,
                'draftDate' => '2023-05-16T14:55:01+00:00',
                'toDate' => nil,
                'hasAttachments' => false,
                'replyDisabled' => false
              },
              'links' => {
                'self' => 'http://www.example.com/mobile/v0/messaging/health/messages/573041'
              }
            }
          ],
        'meta' => {
          'messageCounts' => {
            'read' => 3
          }
        } }
    end

    describe '#thread' do
      let(:thread_id) { 573_059 }

      it 'includes provided message' do
        VCR.use_cassette('mobile/messages/v1_get_thread') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread", headers: sis_headers
        end

        expect(response).to be_successful
        expect(response.parsed_body).to eq(thread_response)
        expect(response.parsed_body['data'].any? { |m| m['id'] == thread_id.to_s }).to be true
      end

      it 'includes replyDisabled' do
        VCR.use_cassette('mobile/messages/v1_get_thread_reply_disabled') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread", headers: sis_headers
        end

        expect(response).to be_successful
        # messages with reply_disabled: false, true, nil
        expect(response.parsed_body['data'].map { |msg| msg['attributes']['replyDisabled'] }).to eq [false, true, false]
      end

      it 'filters the provided message when excludeProvidedMessage is true' do
        VCR.use_cassette('mobile/messages/v1_get_thread') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread",
              headers: sis_headers,
              params: { excludeProvidedMessage: true }
        end

        expect(response).to be_successful
        expect(response.parsed_body['data']).to eq(thread_response['data'].filter { |m| m['id'] != thread_id.to_s })
        expect(response.parsed_body['data'].any? { |m| m['id'] == thread_id.to_s }).to be false
      end

      it 'does not filter the provided message when excludeProvidedMessage is false' do
        VCR.use_cassette('mobile/messages/v1_get_thread') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread",
              headers: sis_headers,
              params: { excludeProvidedMessage: false }
        end

        expect(response).to be_successful
        expect(response.parsed_body).to eq(thread_response)
        expect(response.parsed_body['data'].any? { |m| m['id'] == thread_id.to_s }).to be true
      end

      it 'provides a count in the meta of read' do
        VCR.use_cassette('mobile/messages/v1_get_thread') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread",
              headers: sis_headers,
              params: { excludeProvidedMessage: true }
        end

        # the previous count was 3, but that included an invalid message
        # it should be 2 because there's only 2 valid messages (both READ)
        expect(response.parsed_body.dig('meta', 'messageCounts', 'read')).to eq(2)
      end
    end
  end
end
