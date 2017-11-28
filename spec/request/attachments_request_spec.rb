# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  let(:mhv_account) { double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, accessible?: true) }
  let(:current_user) { build(:user, :mhv) }
  let(:user_id) { '10616687' }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
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
