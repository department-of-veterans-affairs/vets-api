# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Threads Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_059 }
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
end
