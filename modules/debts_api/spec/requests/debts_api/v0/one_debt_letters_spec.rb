# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DebtsApi::V0::DigitalDisputes', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#download_pdf' do
    it 'returns pdf' do
      expect(StatsD).to receive(:increment).with(
        'api.rack.request',
        { tags: %w[controller:debts_api/v0/one_debt_letters action:download_pdf source_app:not_provided status:200] }
      )
      get '/debts_api/v0/download_one_debt_letter_pdf'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
    end
  end
end
