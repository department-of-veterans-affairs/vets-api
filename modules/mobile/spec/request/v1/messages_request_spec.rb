# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/helpers/sis_session_helper'
require_relative '../../support/helpers/mobile_sm_client_helper'

RSpec.describe 'Mobile Messages V1 Integration', type: :request do
  include Mobile::MessagingClientHelper

  let!(:user) { sis_user(:mhv, :api_auth, mhv_correlation_id: '123', mhv_account_type:) }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/categories', headers: sis_headers
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }
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
                'draftDate' => '2023-05-16T14:55:01.000+00:00',
                'toDate' => nil,
                'hasAttachments' => false
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
                'draftDate' => '2023-05-16T14:55:01.000+00:00',
                'toDate' => nil,
                'hasAttachments' => false
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
                'draftDate' => '2023-05-16T14:55:01.000+00:00',
                'toDate' => nil,
                'hasAttachments' => false
              },
              'links' => {
                'self' => 'http://www.example.com/mobile/v0/messaging/health/messages/573041'
              }
            }
          ] }
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

      it 'filters the provided message' do
        VCR.use_cassette('mobile/messages/v1_get_thread') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread",
              headers: sis_headers,
              params: { excludeProvidedMessage: true }
        end

        expect(response).to be_successful
        expect(response.parsed_body['data']).to eq(thread_response['data'].filter { |m| m['id'] != thread_id.to_s })
        expect(response.parsed_body['data'].any? { |m| m['id'] == thread_id.to_s }).to be false
      end
    end
  end
end
