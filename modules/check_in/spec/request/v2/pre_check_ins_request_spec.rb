# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::PreCheckInsController', type: :request do
  let(:id) { '2f90aa72-deba-4bd7-9bd6-5d17c70bb1b3' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_pre_check_in_enabled').and_return(true)
    Rails.cache.clear
  end

  describe 'POST `create`' do
    it 'returns not implemented' do
      post '/check_in/v2/pre_check_ins', {}

      expect(response.status).to eq(501)
    end
  end

  describe 'GET `show`' do
    it 'returns not implemented' do
      get "/check_in/v2/pre_check_ins/#{id}"

      expect(response.status).to eq(501)
    end
  end
end
