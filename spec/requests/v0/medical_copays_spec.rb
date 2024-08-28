# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::MedicalCopays', type: :request do
  let(:current_user) { build(:user, :loa3) }

  before do
    sign_in_as(current_user)
  end

  describe 'GET medical_copays#index' do
    let(:copays) { { data: [], status: 200 } }

    it 'returns a formatted hash response' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(copays)

      get '/v0/medical_copays'

      expect(Oj.load(response.body)).to eq({ 'data' => [], 'status' => 200 })
    end
  end
end
