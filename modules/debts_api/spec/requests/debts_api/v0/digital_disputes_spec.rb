# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DebtsApi::V0::DigitalDisputes', type: :request do
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#create' do
    let(:params) do
      get_fixture_absolute('modules/debts_api/spec/fixtures/digital_disputes/standard_submission')
    end

    it 'returns digital_disputes_params' do
      post(
        '/debts_api/v0/digital_disputes',
        params: params,
        as: :json
      )

      expect(response).to have_http_status(:ok)
    end
  end
end
