# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(SM::Client).to receive(:new).once.and_return(authenticated_client)
  end

  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  describe '#index' do
    it 'responds with all messages in a folder when no pagination is given' do
      VCR.use_cassette("sm/messages/#{user_id}/index") do
        get "/v0/messaging/health/folders/#{inbox_id}/messages"
      end
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end

  describe '#show' do
    context 'with valid id' do
      it 'responds to GET #show' do
        VCR.use_cassette("sm/messages/#{user_id}/show") do
          get "/v0/messaging/health/messages/#{message_id}"
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end
  end

  describe '#create' do
    let(:message_attributes) { attributes_for(:message).slice(:subject, :category, :recipient_id, :body) }
    let(:params) { { message: message_attributes } }

    context 'with valid attributes' do
      it 'responds to POST #create' do
        VCR.use_cassette("sm/messages/#{user_id}/create") do
          post '/v0/messaging/health/messages', params
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end

      it 'subject defaults to general query' do
        VCR.use_cassette("sm/messages/#{user_id}/create_no_subject") do
          post '/v0/messaging/health/messages', message: message_attributes.slice(:recipient_id, :category, :body)
        end

        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
        expect(JSON.parse(response.body)['data']['attributes']['subject']).to eq('General Inquiry')
      end
    end

    context 'with missing attributes' do
      it 'requires a recipient_id' do
        post '/v0/messaging/health/messages', message: message_attributes.slice(:subject, :category, :body)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to_not be_success
        expect(errors['title']).to eq("Recipient can't be blank")
        expect(errors['code']).to eq('100')
        expect(errors['status']).to eq(422)
      end

      it 'requires a body' do
        post '/v0/messaging/health/messages', message: message_attributes.slice(:subject, :category, :recipient_id)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to_not be_success
        expect(errors['title']).to eq("Body can't be blank")
        expect(errors['code']).to eq('100')
        expect(errors['status']).to eq(422)
      end

      it 'requires a category' do
        post '/v0/messaging/health/messages', message: message_attributes.slice(:subject, :body, :recipient_id)

        errors = JSON.parse(response.body)['errors'].first

        expect(response).to_not be_success
        expect(errors['title']).to eq("Category can't be blank")
        expect(errors['code']).to eq('100')
        expect(errors['status']).to eq(422)
      end
    end
  end

  describe '#thread' do
    let(:thread_id) { 573_059 }

    it 'responds to GET #thread' do
      VCR.use_cassette("sm/messages/#{user_id}/thread") do
        get "/v0/messaging/health/messages/#{thread_id}/thread"
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end

  describe 'when getting categories' do
    it 'responds to GET messages/categories' do
      VCR.use_cassette("sm/messages/#{user_id}/category") do
        get '/v0/messaging/health/messages/categories'
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('category')
    end
  end
end
