# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/stub_financial_status_report'
require_relative '../../../support/financial_status_report_helpers'

RSpec.describe 'DebtsApi::V0::FinancialStatusReports requesting', type: :request do
  let(:service_class) { DebtsApi::V0::FinancialStatusReportService }
  let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
  let(:user) { build(:user, :loa3) }
  let(:filenet_id) { '93631483-E9F9-44AA-BB55-3552376400D8' }

  before do
    sign_in_as(user)
    mock_pdf_fill
  end

  def mock_pdf_fill
    pdf_stub = class_double(PdfFill::Filler).as_stubbed_const
    allow(pdf_stub).to receive(:fill_ancillary_form).and_return(Rails.root.join(*'/spec/fixtures/dmc/5655.pdf'
                                                                                   .split('/')).to_s)
  end

  describe '#create' do
    context 'when service raises FSRNotFoundInRedis' do
      before do
        expect_any_instance_of(service_class).to receive(
          :submit_financial_status_report
        ).and_raise(
          service_class::FSRNotFoundInRedis
        )
      end

      it 'renders 404' do
        post('/debts_api/v0/financial_status_reports', params: valid_form_data)
        expect(response).to have_http_status(:not_found)
        expect(response.header['Content-Type']).to include('application/json')
        expect(JSON.parse(response.body)).to eq(nil)
      end
    end

    it 'submits a financial status report' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          post('/debts_api/v0/financial_status_reports', params: valid_form_data.to_h, as: :json)
          expect(response.code).to eq('200')
        end
      end
    end
  end

  describe '#download_pdf' do
    stub_financial_status_report(:download_pdf)

    it 'downloads the filled financial status report pdf' do
      set_filenet_id(user:, filenet_id:)
      get '/debts_api/v0/financial_status_reports/download_pdf'
      expect(response.header['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(content)
    end
  end
end
