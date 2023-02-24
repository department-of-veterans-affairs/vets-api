# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Threads Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 660_516 }
  let(:thread_id) { 660_515 }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient: va_patient, mhv_account_type: mhv_account_type) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { patch '/my_health/v1/messaging/threads/7259506/move?folder_id=0' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { patch '/my_health/v1/messaging/threads/7259506/move?folder_id=0' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before do
        get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
            params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
      end

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient: va_patient, mhv_account_type: mhv_account_type)
      end

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    describe '#index' do
      context 'with valid params' do
        it 'responds to GET #index' do
          VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder') do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_response_schema('message_threads')
        end

        it 'responds to GET #index when camel-inflected' do
          VCR.use_cassette('sm_client/threads/gets_threads_in_a_folder_camel') do
            get "/my_health/v1/messaging/folders/#{inbox_id}/threads",
                params: { page_size: '5', page_number: '1', sort_field: 'SENDER_NAME', sort_order: 'ASC' },
                headers: { 'X-Key-Inflection' => 'camel' }
          end

          expect(response).to be_successful
          expect(response.body).to be_a(String)
          expect(response).to match_camelized_response_schema('message_threads')
        end
      end
    end

    describe '#move' do
      let(:thread_id) { 7_065_799 }

      it 'responds to PATCH threads/move' do
        VCR.use_cassette('sm_client/threads/moves_a_thread_with_id') do
          patch "/my_health/v1/messaging/threads/#{thread_id}/move?folder_id=0"
        end

        puts response
        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
