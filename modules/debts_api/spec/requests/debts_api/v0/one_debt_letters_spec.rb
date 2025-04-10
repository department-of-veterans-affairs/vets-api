# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DebtsApi::V0::DigitalDisputes', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#download_pdf' do
    before do
      vbs_service_double = instance_double(MedicalCopays::VBS::Service)
      allow(vbs_service_double).to receive(:get_copays).and_return({ data: [] })
      allow(MedicalCopays::VBS::Service).to receive(:build).and_return(vbs_service_double)
    end

    it 'returns pdf' do
      VCR.use_cassette('bgs/people_service/person_data') do
        VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
          post '/debts_api/v0/combine_one_debt_letter_pdf', params: {}

          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/pdf')
        end
      end
    end
  end
end
