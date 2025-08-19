# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::MedicalCopays', type: :request do
  let!(:user) { sis_user }

  describe 'GET medical_copays#index' do
    let(:copays) { { data: [], status: 200 } }

    it 'returns a formatted hash response' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(copays)

      get '/mobile/v0/medical_copays', headers: sis_headers

      expect(Oj.load(response.body)).to eq({ 'data' => [], 'status' => 200 })
    end
  end

  describe 'GET medical_copays#show' do
    let(:copay) { { data: {}, status: 200 } }

    it 'returns a formatted hash response' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copay_by_id).and_return(copay)

      get '/mobile/v0/medical_copays/abc123', headers: sis_headers

      expect(Oj.load(response.body)).to eq({ 'data' => {}, 'status' => 200 })
    end
  end
end
