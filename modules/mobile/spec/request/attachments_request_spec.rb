# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/helpers/mobile_sm_client_helper'

RSpec.describe 'Mobile Message Attachments Integration', type: :request do
  include Mobile::MessagingClientHelper

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
    iam_sign_in(build(:iam_user, iam_mhv_id: '123'))
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/629999/attachments/629993', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      get '/mobile/v0/messaging/health/messages/629999/attachments/629993', headers: iam_headers
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    describe '#show' do
      it 'responds sending data for an attachment' do
        VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
          get '/mobile/v0/messaging/health/messages/629999/attachments/629993', headers: iam_headers
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
end
