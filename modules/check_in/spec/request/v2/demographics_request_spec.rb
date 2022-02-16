# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V2::Demographics', type: :request do
  let(:id) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }

  describe 'PATCH `update`' do
    it 'returns not implemented' do
      patch "/check_in/v2/demographics/#{id}"

      expect(response.status).to eq(501)
    end
  end
end
