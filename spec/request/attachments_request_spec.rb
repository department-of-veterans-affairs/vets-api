# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'sm', type: :request do
  context 'messages/nested_resources' do
    before(:each) do
      allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    end

    let(:inbox_id) { 0 }
    let(:message_id) { 573_302 }

    it 'responds to GET #show of attachments', :vcr do
      get '/v0/messaging/health/messages/629999/attachments/629993'

      expect(response).to be_success
      expect(response.headers['Content-Disposition'])
        .to eq('attachment; filename="noise300x200.png"')
      expect(response.headers['Content-Transfer-Encoding']).to eq('binary')
      expect(response.headers['Content-Type']).to eq('image/png')
      expect(response.body).to be_a(String)
    end
  end
end
