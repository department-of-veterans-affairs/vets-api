# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

describe SM::Client do
  include SM::ClientHelpers

  subject(:client) { authenticated_client }

  it 'should have #get_message(message_id)' do
    VCR.use_cassette('sm/messages/responds_to_GET_show') do
      client_response = client.get_message(573_302)
      expect(client_response).to be_a(Message)
    end
  end

  it 'should have #get_message_history(message_id)' do
    VCR.use_cassette('sm/messages/responds_to_GET_thread') do
      client_response = client.get_message_history(573_059)
      expect(client_response).to be_a(Common::Collection)
      expect(client_response.type).to eq(Message)
    end
  end

  it 'should have #get_message_category' do
    VCR.use_cassette('sm/messages/responds_to_GET_categories') do
      client_response = client.get_message_category
      expect(client_response).to be_a(Category)
      expect(client_response.message_category_type).to contain_exactly(
        'OTHER', 'APPOINTMENTS', 'MEDICATIONS', 'TEST_RESULTS', 'EDUCATION'
      )
    end
  end
end
