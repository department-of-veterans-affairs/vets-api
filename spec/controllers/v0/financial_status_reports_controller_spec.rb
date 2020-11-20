# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::FinancialStatusReportsController, type: :controller do
  let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#create' do
    it 'submits a financial status report' do
      VCR.use_cassette('dmc/submit_fsr') do
        post(:create, params: valid_form_data)
        expect(response.code).to eq('200')
      end
    end
  end
end
