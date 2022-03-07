# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/financial_status_report_service'
require 'debt_management_center/workers/va_notify_email_job'
require 'support/financial_status_report_helpers'

RSpec.describe DebtManagementCenter::FinancialStatusReportService, type: :service do
  it 'inherits SentryLogging' do
    expect(described_class.ancestors).to include(SentryLogging)
  end

  describe '#submit_financial_status_report' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let(:user) { build(:user, :loa3) }
    let(:malformed_form_data) do
      { 'bad' => 'data' }
    end

    context 'with valid form data' do
      it 'accepts the submission' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            res = service.submit_financial_status_report(valid_form_data)
            expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
          end
        end
      end

      it 'sends a confirmation email' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
              user.email.downcase,
              described_class::CONFIRMATION_TEMPLATE,
              {
                'name' => user.first_name,
                'time' => '48 hours',
                'date' => Time.zone.now.strftime('%m/%d/%Y')
              }
            )
            service.submit_financial_status_report(valid_form_data)
          end
        end
      end
    end

    context 'with malformed form' do
      it 'does not accept the submission' do
        VCR.use_cassette('dmc/submit_fsr_error') do
          VCR.use_cassette('bgs/people_service/person_data') do
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

    context 'when saving FSR fails' do
      subject { described_class.new(user) }

      before do
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry) do |_self, arg_1, arg_2|
          expect(arg_1).to be_instance_of(ActiveModel::ValidationError)
          expect(arg_1.message).to eq('Validation failed: Filenet can\'t be blank')
          expect(arg_2).to eq(
            {
              fsr_attributes: {
                uuid: 'b2fab2b5-6af0-45e1-a9e2-394347af91ef',
                filenet_id: nil
              },
              fsr_response: {
                response_body: {
                  'status' => 'Document created successfully and uploaded to File Net.'
                }
              }
            }
          )
        end
      end

      it 'logs to sentry' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            res = subject.submit_financial_status_report(valid_form_data)
            expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
          end
        end
      end
    end
  end

  describe '#get_pdf' do
    let(:filenet_id) { 'ABCD-1234' }
    let(:user) { build(:user, :loa3) }

    context 'when FSR is missing from redis' do
      it 'raises an error' do
        VCR.use_cassette('bgs/people_service/person_data') do
          service = described_class.new(user)
          expect { service.get_pdf }.to raise_error do |error|
            expect(error).to be_instance_of(described_class::FSRNotFoundInRedis)
          end
        end
      end
    end

    context 'with logged in user' do
      it 'downloads the pdf' do
        set_filenet_id(user: user, filenet_id: filenet_id)

        VCR.use_cassette('dmc/download_pdf') do
          VCR.use_cassette('bgs/people_service/person_data') do
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
end
