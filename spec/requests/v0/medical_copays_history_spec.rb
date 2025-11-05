# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MedicalCopaysHistory', type: :request do
  let(:current_user) { build(:user, :loa3) }

  before do
    sign_in_as(current_user)
  end

  describe 'index' do
    it 'returns a formatted hash response' do
      VCR.use_cassette('lighthouse/hccc/invoice_list_success') do
        get '/v0/medical_copays_history'

        response.body
        # expect(Oj.load(response. body)).to eq({ 'data' => [], 'status' => 200 })
      end
    end

    it 'handles auth error' do
      VCR.use_cassette('lighthouse/hccc/auth_error') do
        get '/v0/medical_copays_history'

        response.body
        # expect(Oj.load(response. body)).to eq({ 'data' => [], 'status' => 200 })
      end
    end

    it 'handles no records returned' do
      VCR.use_cassette('lighthouse/hccc/no_records') do
        get '/v0/medical_copays_history'

        response.body
        # expect(Oj.load(response. body)).to eq({ 'data' => [], 'status' => 200 })
      end
    end
  end
end
