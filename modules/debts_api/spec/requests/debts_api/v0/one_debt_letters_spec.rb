# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/one_debt_letter_service'

RSpec.describe 'DebtsApi::V0::OneDebtLetters', type: :request do
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

    context 'combine pdf' do
      let(:file) do
        Rack::Test::UploadedFile.new(
          Rails.root.join('modules', 'debts_api', 'spec', 'fixtures', '5655.pdf'),
          'application/pdf'
        )
      end

      it 'increments StatsD' do
        allow(StatsD).to receive(:increment)

        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::OneDebtLetterService::STATS_KEY}.initiated"
        )

        expect(StatsD).to receive(:increment).with(
          "#{DebtsApi::V0::OneDebtLetterService::STATS_KEY}.success"
        )

        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            post '/debts_api/v0/combine_one_debt_letter_pdf', params: { document: file }
          end
        end
      end
    end
  end
end
