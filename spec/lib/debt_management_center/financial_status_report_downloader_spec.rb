# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/financial_status_report_downloader'
require 'debt_management_center/models/financial_status_report'

RSpec.describe DebtManagementCenter::FinancialStatusReportDownloader do
  subject { described_class.new(fsr) }

  let(:user) { build(:user, :loa3) }
  let(:filenet_id) { 'ABCD-1234' } # Must match cassette
  let(:fsr_params) { { REDIS_CONFIG[:financial_status_report][:namespace] => user.uuid } }
  let(:fsr) { DebtManagementCenter::FinancialStatusReport.new(fsr_params) }

  describe '#download_pdf' do
    context 'with an missing filenet id' do
      it 'raises an error' do
        subject = described_class.new(fsr)
        expect { subject.download_pdf }.to raise_error do |error|
          expect(error).to be_instance_of(described_class::FilenetIdNotPresent)
        end
      end
    end

    context 'with an nil filenet id' do
      before { fsr.update(filenet_id: nil, uuid: user.uuid) }

      it 'raises an error' do
        expect { subject.download_pdf }.to raise_error do |error|
          expect(error).to be_instance_of(described_class::FilenetIdNotPresent)
        end
      end
    end

    context 'with an empty filenet id' do
      before { fsr.update(filenet_id: '', uuid: user.uuid) }

      it 'raises an error' do
        subject = described_class.new(fsr)
        expect { subject.download_pdf }.to raise_error do |error|
          expect(error).to be_instance_of(described_class::FilenetIdNotPresent)
        end
      end
    end

    context 'with a valid filenet id' do
      before do
        fsr.update(filenet_id:, uuid: user.uuid)
      end

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
