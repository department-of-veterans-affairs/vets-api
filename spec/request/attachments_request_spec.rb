# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

RSpec.describe 'Messages Integration', type: :request do
  let(:current_user) { build(:mhv_user) }
  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  before(:each) do
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
