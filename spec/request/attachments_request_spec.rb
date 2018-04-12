# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Message Attachments Integration', type: :request do
  include SM::ClientHelpers

  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient: va_patient, mhv_account_type: mhv_account_type) }
  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before(:each) do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }
    before(:each) { get '/v0/messaging/health/messages/629999/attachments/629993' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for user that is not a va patient', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }
    before(:each) { get '/v0/messaging/health/messages/629999/attachments/629993' }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for user that is not a va patient', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before(:each) { get '/v0/messaging/health/messages/629999/attachments/629993' }
      let(:va_patient) { false }

      include_examples 'for user that is not a va patient', authorized: false, message: 'You do not have access to messaging'
    end

    describe '#show' do
      it 'responds sending data for an attachment' do
        VCR.use_cassette('sm_client/messages/nested_resources/gets_a_single_attachment_by_id') do
          get '/v0/messaging/health/messages/629999/attachments/629993'
        end

        expect(response).to be_success
        expect(response.headers['Content-Disposition'])
          .to eq('attachment; filename="noise300x200.png"')
        expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
        expect(response.headers['Content-Type']).to eq('image/png')
        expect(response.body).to be_a(String)
      end
    end
  end
end
