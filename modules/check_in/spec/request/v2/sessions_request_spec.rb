# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::SessionsController', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?)
      .with('check_in_experience_multiple_appointment_support').and_return(true)

    Rails.cache.clear
  end

  describe 'GET `show`' do
    it 'returns not implemented' do
      get "/check_in/v2/sessions/#{id}"

      expect(response.status).to eq(501)
    end
  end

  describe 'POST `create`' do
    it 'returns not implemented' do
      post '/check_in/v2/sessions', {}

      expect(response.status).to eq(501)
    end
  end
end
