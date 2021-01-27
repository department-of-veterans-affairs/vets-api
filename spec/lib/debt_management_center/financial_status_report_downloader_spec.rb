# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/financial_status_report_downloader'
require 'debt_management_center/models/financial_status_report'

RSpec.describe DebtManagementCenter::FinancialStatusReportDownloader do
  subject { described_class.new(financial_status_report) }

  let(:user) { build(:user, :loa3) }
  let(:filenet_id) { 'ABCD-1234' }
  let(:financial_status_report) do
    report_params = Hash[REDIS_CONFIG[:financial_status_report][:namespace], user.uuid]
    financial_status_report = DebtManagementCenter::FinancialStatusReport.new(report_params)
    financial_status_report.update(filenet_id: filenet_id, uuid: user.uuid)
    financial_status_report
  end

  describe '#download_pdf' do
    context 'with a valid filenet id' do
      it 'downloads the pdf' do
        VCR.use_cassette('dmc/download_pdf') do
          expect(subject.download_pdf.force_encoding('ASCII-8BIT')).to eq(
            File.read(
              Rails.root.join('spec', 'fixtures', 'dmc', '5655.pdf')
            ).force_encoding('ASCII-8BIT')
          )
        end
      end
    end
  end
end
