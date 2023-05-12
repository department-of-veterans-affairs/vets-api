# frozen_string_literal: true

require 'debts_api/v0/financial_status_report_service'

def stub_financial_status_report(method)
  let!(:financial_status_report_service) do
    financial_status_report_service = double
    expect(
      DebtsApi::V0::FinancialStatusReportService
    ).to receive(:new).and_return(financial_status_report_service)
    financial_status_report_service
  end

  if method == :download_pdf
    let(:content) { File.read('modules/debts_api/spec/fixtures/5655.pdf').force_encoding('ASCII-8BIT') }

    before do
      expect(financial_status_report_service).to receive(:get_pdf).and_return(content)
    end
  end
end
