# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    # expect(SM::Client).to receive(:new).once.and_return(authenticated_client)
  end

  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  describe '#show' do
    it 'responds sending data for an attachment' do
      VCR.use_cassette("sm/messages/#{user_id}/attachments/show") do
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
