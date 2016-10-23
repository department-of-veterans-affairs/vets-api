# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

RSpec.describe 'sm', type: :request do
  describe 'folders' do
    let(:inbox_id) { 0 }
    # When re-recording cassettes:
    # identify the id of the created folder and delete the same one in the next spec
    # make sure to run rspec in default order (not rand),
    # or run each spec individually (create first)
    # bundle exec rspec --order default
    let(:params_for_create) { { folder: { name: "test folder #{rand(100..10000)}" } } }
    let(:destroy_folder_id) { 653164 }

    before(:each) do
      allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    end

    it 'responds to GET #index', :vcr do
      get '/v0/messaging/health/folders'

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('folders')
    end

    it 'responds to GET #show', :vcr do
      get "/v0/messaging/health/folders/#{inbox_id}"

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('folder')
    end

    context 'non idempotent actions' do
      it 'responds to POST #create', :vcr do
        post '/v0/messaging/health/folders', params_for_create

        expect(response).to be_success
        expect(response).to have_http_status(:created)
        expect(response).to match_response_schema('folder')
      end

      it 'responds to DELETE #destroy', :vcr do
        delete "/v0/messaging/health/folders/#{destroy_folder_id}"

        expect(response).to be_success
        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'nested resources' do
    describe 'responds to GET index of messages' do
      let(:inbox_id) { 0 }
      let(:filter_attributes) { 'filter[[subject][eq]]=something&filter[[sender_name][eq]]=someone' }
      let(:filter_predicates) { 'filter[[sent_date][lteq]]=2016-01-01&filter[[sent_date][gteq]]=2016-01-01' }

      it 'complete collection', :vcr do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('messages')
      end

      it 'filtered for multiple attributes', :vcr do
        get "/v0/messaging/health/folders/#{inbox_id}/messages?#{filter_attributes}"
        expect(response).to be_success
      end

      it 'filtered for multiple predicates on single field', :vcr do
        get "/v0/messaging/health/folders/#{inbox_id}/messages?#{filter_predicates}"
        expect(response).to be_success
      end
    end
  end
end
