# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/financial_status_report_service'
require 'support/financial_status_report_helpers'

RSpec.describe DebtManagementCenter::FinancialStatusReportService, type: :service do
  describe '#submit_financial_status_report' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let(:user) { build(:user, :loa3) }
    let(:malformed_form_data) do
      { 'bad' => 'data' }
    end

    context 'with valid form data' do
      it 'accepts the submission' do
        VCR.use_cassette('dmc/submit_fsr') do
          service = described_class.new(user)
          res = service.submit_financial_status_report(valid_form_data)
          expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
        end
      end
    end

    context 'with malformed form' do
      it 'does not accept the submission' do
        VCR.use_cassette('dmc/submit_fsr_error') do
          service = described_class.new(user)
          expect { service.submit_financial_status_report(malformed_form_data) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) do |e|
            expect(e.message).to match(/DMC400/)
          end
        end
      end
    end
  end

  describe '#get_pdf' do
    let(:filenet_id) { 'ABCD-1234' }
    let(:user) { build(:user, :loa3) }

    context 'with logged in user' do
      it 'downloads the pdf' do
        set_filenet_id(user: user, filenet_id: filenet_id)

        VCR.use_cassette('dmc/download_pdf') do
          service = described_class.new(user)
          expect(service.get_pdf.force_encoding('ASCII-8BIT')).to eq(
            File.read(
              Rails.root.join('spec', 'fixtures', 'dmc', '5655.pdf')
            ).force_encoding('ASCII-8BIT')
          )
        end
      end
    end
  end
end
