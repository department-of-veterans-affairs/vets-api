# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../../../debts_api/lib/debts_api/v0/financial_status_report_service'

RSpec.describe 'Mobile::V0::FinancialStatusReports', :skip_json_api_validation, type: :request do
  let!(:user) { sis_user }

  describe 'POST /mobile/v0/financial-status-reports/download' do
    context 'with an existing file' do
      let(:content) { File.read('modules/debts_api/spec/fixtures/5655.pdf').force_encoding('ASCII-8BIT') }

      before do
        expect_any_instance_of(DebtsApi::V0::FinancialStatusReportService).to receive(:get_pdf).and_return(content)
        pdf = DebtManagementCenter::FinancialStatusReport.find_or_build(user.uuid)
        pdf.update(filenet_id: '93631483-E9F9-44AA-BB55-3552376400D8', uuid: user.uuid)
      end

      it 'returns financial status report pdf' do
        post '/mobile/v0/financial-status-reports/download', headers: sis_headers
        expect(response).to have_http_status(:ok)
        expect(response.header['Content-Type']).to eq('application/pdf')
        expect(response.body).to eq(content)
      end
    end

    context 'with a non-existent file' do
      it 'returns not found error' do
        post '/mobile/v0/financial-status-reports/download', headers: sis_headers
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to be_nil
      end
    end
  end
end
