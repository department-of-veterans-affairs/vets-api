# frozen_string_literal: true

def stub_financial_status_report
  let!(:financial_status_report_service) do
    financial_status_report_service = double
    expect(
      DebtManagementCenter::FinancialStatusReportService
    ).to receive(:new).and_return(financial_status_report_service)
    financial_status_report_service
  end

  if method == :get_pdf
    let(:document_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(financial_status_report_service).to receive(:get_pdf).with(document_id).and_return(content)
    end
  end
end
