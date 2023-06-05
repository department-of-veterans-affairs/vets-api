# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/helpers/mobile_sm_client_helper'

RSpec.describe 'Mobile Messages Integration', type: :request do
  include Mobile::MessagingClientHelper
  include SchemaMatchers

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
      get "/mobile/v0/messaging/health/folders/#{inbox_id}/threads",
          headers: iam_headers,
          params: { page_size: '5', page: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get "/mobile/v0/messaging/health/folders/#{inbox_id}/threads",
          headers: iam_headers,
          params: { page_size: '5', page: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }
    let(:example_thread) do
      { 'id' => '7298505',
        'type' => 'message_threads',
        'attributes' =>
         { 'threadId' => 7_298_505,
           'folderId' => 0,
           'messageId' => 7_298_506,
           'threadPageSize' => 454,
           'messageCount' => 1,
           'category' => 'EDUCATION',
           'subject' => 'Education Inquiry',
           'triageGroupName' => 'WORKLOAD CAPTURE_SLC 4_Mohammad',
           'sentDate' => '2023-02-15T17:01:55.000Z',
           'draftDate' => nil,
           'senderId' => 20_029,
           'senderName' => 'ISLAM, MOHAMMAD  RAFIQ',
           'recipientName' => 'ECSTEN, THOMAS ',
           'recipientId' => 6_820_911,
           'proxySenderName' => nil,
           'hasAttachment' => false,
           'unsentDrafts' => false,
           'unreadMessages' => false },
        'links' => { 'self' => 'http://www.example.com/my_health/v1/messaging/threads/7298505' } }
    end

    it 'responds to GET #index' do
      VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder') do
        get "/mobile/v0/messaging/health/folders/#{inbox_id}/threads",
            headers: iam_headers,
            params: { page_size: '5', page: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
      end

      expect(response).to be_successful
      first_thread = response.parsed_body.dig('data', 0)
      expect(first_thread).to match(example_thread)
    end

    it 'responds 400 to GET #index with none existent folder' do
      VCR.use_cassette('mobile/messages/get_threads_in_folder_400') do
        get '/mobile/v0/messaging/health/folders/100/threads',
            headers: iam_headers,
            params: { page_size: '5', page: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
      end

      expect(response).to have_http_status(:bad_request)
    end
  end
end
