# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Message Attachments Integration' do
  include SM::ClientHelpers

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }
  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { get '/v0/messaging/health/messages/629999/attachments/629993' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { get '/v0/messaging/health/messages/629999/attachments/629993' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { get '/v0/messaging/health/messages/629999/attachments/629993' }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
      end

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    describe '#show' do
      it 'responds sending data for an attachment' do
        VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
          get '/v0/messaging/health/messages/629999/attachments/629993'
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
