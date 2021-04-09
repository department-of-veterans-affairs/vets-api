# frozen_string_literal: true

require 'rails_helper'
require 'support/stub_financial_status_report'
require 'support/financial_status_report_helpers'

RSpec.describe V0::FinancialStatusReportsController, type: :controller do
  let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
  let(:user) { build(:user, :loa3) }
  let(:filenet_id) { '93631483-E9F9-44AA-BB55-3552376400D8' }

  before do
    sign_in_as(user)
  end

  describe '#create' do
    it 'submits a financial status report' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          post(:create, params: valid_form_data)
          expect(response.code).to eq('200')
        end
      end
    end
  end

  describe '#download_pdf' do
    stub_financial_status_report(:download_pdf)

    it 'downloads the filled financial status report pdf' do
      set_filenet_id(user: user, filenet_id: filenet_id)
      get(:download_pdf)
      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(content)
    end
  end
end
