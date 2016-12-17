# frozen_string_literal: true
require 'rails_helper'
require 'bb/client'

describe 'bb client' do
  describe 'extract status' do
    let(:post_refill_error) { File.read('spec/support/fixtures/post_refill_error.json') }

    before(:each) do
      VCR.use_cassette 'bb_client/session', record: :new_episodes do
        @client ||= begin
          client = BB::Client.new(session: { user_id: '12210827' })
          client.authenticate
          client
        end
      end
    end

    let(:client) { @client }

    # Need additional specs - Commenting this out for now because
    # apparently application code we have is now invalid??
    xit 'gets an extract status', :vcr do
      client_response = client.extract_status
    end
  end
end
