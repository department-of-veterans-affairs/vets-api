# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/iam_session_helper'
require_relative '../../support/mobile_sm_client_helper'
require_relative '../../support/matchers/json_schema_matcher'

RSpec.describe 'Mobile Messages V1 Integration', type: :request do
  include Mobile::MessagingClientHelper
  include JsonSchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
  let(:va_patient) { true }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
    iam_sign_in(build(:iam_user, iam_mhv_id: '123'))
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/categories', headers: iam_headers
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/categories', headers: iam_headers
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
              'id' => '573052',
              'type' => 'message_thread_details',
              'attributes' => {
                'messageId' => 573_052,
                'category' => 'OTHER',
                'subject' => 'Release 16.2- SM last login ',
                'body' => 'Provider Reply',
                'attachment' => false,
                'sentDate' => '2016-04-11T15:49:03.000Z',
                'senderId' => 257_555,
                'senderName' => 'ISLAM, MOHAMMAD',
                'recipientId' => 384_939,
                'recipientName' => 'MVIONE, TEST',
                'readReceipt' => 'READ',
                'triageGroupName' => nil,
                'proxySenderName' => nil
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
                'attachment' => false,
                'sentDate' => '2016-04-11T15:48:25.000Z',
                'senderId' => 384_939,
                'senderName' => 'MVIONE, TEST',
                'recipientId' => 345_468,
                'recipientName' => 'WORKLOAD CAPTURE_Mohammad',
                'readReceipt' => 'READ',
                'triageGroupName' => nil,
                'proxySenderName' => nil
              },
              'links' => {
                'self' => 'http://www.example.com/mobile/v0/messaging/health/messages/573041'
              }
            }
          ] }
    end

    describe '#thread' do
      let(:thread_id) { 573_059 }

      it 'responds to GET #thread' do
        VCR.use_cassette('mobile/messages/v1_get_thread') do
          get "/mobile/v1/messaging/health/messages/#{thread_id}/thread", headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.parsed_body).to eq(thread_response)
      end
    end
  end
end
