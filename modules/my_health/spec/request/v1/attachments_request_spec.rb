# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Message Attachments Integration', type: :request do
  include SM::ClientHelpers

  let(:mhv_account_type) { 'Premium' }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before do
    sign_in_as(current_user)
  end

  context 'when sm session policy is enabled' do
    before do
      Flipper.enable(:mhv_sm_session_policy)
      Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
    end

    after do
      Flipper.disable(:mhv_sm_session_policy)
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
      end
    end
  end

  context 'when legacy sm policy' do
    before do
      Flipper.disable(:mhv_sm_session_policy)
      allow(SM::Client).to receive(:new).and_return(authenticated_client)
    end

    context 'Basic User' do
      let(:mhv_account_type) { 'Basic' }

      before { get '/my_health/v1/messaging/messages/629999/attachments/629993' }

      include_examples 'for user account level', message: 'You do not have access to messaging'
      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    context 'Premium User' do
      let(:mhv_account_type) { 'Premium' }

      context 'not a va patient' do
        before { get '/my_health/v1/messaging/messages/629999/attachments/629993' }

        let(:va_patient) { false }
        let(:current_user) do
          build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
        end

        include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
      end

      describe '#show' do
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
      end
    end
  end
end
