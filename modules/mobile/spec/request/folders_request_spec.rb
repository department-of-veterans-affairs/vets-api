# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/mobile_sm_client_helper'

RSpec.describe 'Mobile Folders Integration', type: :request do
  include Mobile::MessagingClientHelper
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
  let(:va_patient) { true }
  # let(:current_user) { build(:user, :mhv, va_patient: va_patient, mhv_account_type: mhv_account_type) }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
    iam_sign_in(build(:iam_user, iam_mhv_id: '123'))
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/folders', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/folders', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    describe '#index' do
      it 'responds to GET #index' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/mobile/v0/messaging/health/folders', headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('folders')
      end

      it 'generates mobile-specific metadata links' do
        VCR.use_cassette('sm_client/folders/gets_a_collection_of_folders') do
          get '/mobile/v0/messaging/health/folders', headers: iam_headers
        end

        result = JSON.parse(response.body)
        folder = result['data'].first
        expect(folder['links']['self']).to match(%r{/mobile/v0})
        expect(result['links']['self']).to match(%r{/mobile/v0})
      end
    end

    describe '#show' do
      context 'with valid id' do
        it 'response to GET #show' do
          VCR.use_cassette('sm_client/folders/gets_a_single_folder') do
            get "/mobile/v0/messaging/health/folders/#{inbox_id}", headers: iam_headers
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('folder')
        end
      end
    end

    describe '#create' do
      context 'with valid name' do
        let(:params) { { folder: { name: 'test folder create name 160805101218' } } }

        it 'response to POST #create' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            post '/mobile/v0/messaging/health/folders', headers: iam_headers, params: params
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:created)
          expect(response).to match_camelized_response_schema('folder')
        end
      end
    end

    describe '#destroy' do
      context 'with valid folder id' do
        let(:id) { 674_886 }

        it 'responds to DELETE #destroy' do
          VCR.use_cassette('sm_client/folders/creates_a_folder_and_deletes_a_folder') do
            delete "/mobile/v0/messaging/health/folders/#{id}", headers: iam_headers
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    describe 'nested resources' do
      it 'gets messages#index' do
        VCR.use_cassette('sm_client/folders/nested_resources/gets_a_collection_of_messages') do
          get "/mobile/v0/messaging/health/folders/#{inbox_id}/messages", headers: iam_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('messages')
      end
    end
  end
end
