# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/financial_status_report_service'
require 'debt_management_center/workers/va_notify_email_job'
require 'debt_management_center/sharepoint/request'
require_relative '../../../support/financial_status_report_helpers'

RSpec.describe DebtsApi::V0::FinancialStatusReportService, type: :service do
  before do
    mock_pdf_fill
  end

  it 'inherits SentryLogging' do
    expect(described_class.ancestors).to include(SentryLogging)
  end

  def mock_sharepoint_upload
    sp_stub = instance_double(DebtManagementCenter::Sharepoint::Request)
    allow(DebtManagementCenter::Sharepoint::Request).to receive(:new).and_return(sp_stub)
    allow(sp_stub).to receive(:upload).and_return(Faraday::Response.new)
  end

  def mock_pdf_fill
    pdf_stub = class_double(PdfFill::Filler).as_stubbed_const
    allow(pdf_stub).to receive(:fill_ancillary_form).and_return(Rails.root.join(
      *'/modules/debts_api/spec/fixtures/5655.pdf'.split('/')
    ).to_s)
  end

  describe '#submit_financial_status_report' do
    let(:valid_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_submission') }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'The flipper is turned on' do
      before do
        Flipper.enable(:combined_financial_status_report)
      end

      it 'submits combined fsr' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            expect(service).to receive(:submit_combined_fsr).with(valid_form_data)
            service.submit_financial_status_report(valid_form_data)
          end
        end
      end
    end

    context 'The flipper is turned off' do
      before do
        Flipper.disable(:combined_financial_status_report)
      end

      it 'ignores flipper and uses combined fsr' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            expect(service).to receive(:submit_combined_fsr).with(valid_form_data)
            service.submit_financial_status_report(valid_form_data)
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
        set_filenet_id(user:, filenet_id:)

        VCR.use_cassette('dmc/download_pdf') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            expect(service.get_pdf.force_encoding('ASCII-8BIT')).to eq(
              Rails.root.join('modules', 'debts_api', 'spec', 'fixtures', '5655.pdf').read.force_encoding('ASCII-8BIT')
            )
          end
        end
      end
    end
  end

  describe '#submit_vba_fsr' do
    let(:valid_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_submission') }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }
    let(:malformed_form_data) do
      { 'bad' => 'data' }
    end

    context 'with valid form data' do
      it 'accepts the submission' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            res = service.submit_vba_fsr(valid_form_data)
            expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
          end
        end
      end

      it 'sends a confirmation email' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
              user_data.email.downcase,
              described_class::VBA_CONFIRMATION_TEMPLATE,
              {
                'name' => user_data.first_name,
                'time' => '48 hours',
                'date' => Time.zone.now.strftime('%m/%d/%Y')
              }
            )
            service.submit_vba_fsr(valid_form_data)
          end
        end
      end
    end

    context 'with malformed form' do
      it 'does not accept the submission' do
        VCR.use_cassette('dmc/submit_fsr_error') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            expect { service.submit_vba_fsr(malformed_form_data) }.to raise_error(Common::Client::Errors::ClientError)
          end
        end
      end
    end

    context 'when saving FSR fails' do
      subject { described_class.new(user_data) }

      before do
        expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry) do |_self, arg1, arg2|
          expect(arg1).to be_instance_of(ActiveModel::ValidationError)
          expect(arg1.message).to eq('Validation failed: Filenet can\'t be blank')
          expect(arg2).to eq(
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
            res = subject.submit_vba_fsr(valid_form_data)
            expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
          end
        end
      end
    end
  end

  describe '#submit_vha_fsr' do
    let(:form_submission) { build(:debts_api_form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }

    before do
      response = Faraday::Response.new(status: 200, body:
      {
        message: 'Success'
      })
      allow_any_instance_of(DebtManagementCenter::VBS::Request).to receive(:post).and_return(response)
      mock_sharepoint_upload
    end

    it 'submits to the VBS endpoint' do
      service = described_class.new(user)
      expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
    end

    it 'parses out delimiter characters' do
      service = described_class.new(user_data)
      delimitered_json = { 'name' => "^Gr\neg|" }
      parsed_form_string = service.send(:remove_form_delimiters, delimitered_json).to_s
      expect(['^', '|', "\n"].any? { |i| parsed_form_string.include? i }).to be false
    end

    context 'with streamlined waiver' do
      let(:form_submission) { build(:debts_api_sw_form5655_submission) }
      let(:non_streamlined_form_submission) { build(:debts_api_non_sw_form5655_submission) }
      let!(:user) { build(:user, :loa3) }

      it 'submits to the VBS endpoint' do
        service = described_class.new(user)
        expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
      end

      it 'makes streamlined the last key in the form hash' do
        service = described_class.new(user)
        adjusted_form = service.send(:streamline_adjustments, form_submission.form)
        expect(adjusted_form.keys.last).to eq('streamlined')
      end

      it 'changes fsrReason for streamlined waivers' do
        service = described_class.new(user)
        adjusted_form = service.send(:streamline_adjustments, form_submission.form)
        expect(adjusted_form['personalIdentification']['fsrReason']).to eq('et, Automatically Approved')
      end

      it 'makes streamlined nil for no flag users' do
        allow(Flipper).to receive(:enabled?).with(:financial_status_report_streamlined_waiver, user).and_return(false)
        service = described_class.new(user)
        form_submission.form['streamlined'].should_not be_nil
        adjusted_form = service.send(:streamline_adjustments, form_submission.form)
        expect(adjusted_form['streamlined']).to be_nil
      end

      it 'does not change fsrReason for non-streamlined waivers' do
        service = described_class.new(user)
        adjusted_form = service.send(:streamline_adjustments, non_streamlined_form_submission.form)
        expect(adjusted_form['personalIdentification']['fsrReason']).not_to eq('Automatically Approved')
      end
    end
  end

  describe '#submit_combined_fsr' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let!(:user) { build(:user, :loa3) }

    before do
      valid_form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      response = Faraday::Response.new(status: 200, body:
      {
        message: 'Success'
      })
      allow_any_instance_of(DebtManagementCenter::VBS::Request).to receive(:post)
        .and_return(response)
      mock_sharepoint_upload
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'enqueues a VBA submission job' do
      valid_form_data['selectedDebtsAndCopays'] = [{ 'foo' => 'bar', 'debtType' => 'DEBT' }]
      valid_form_data['personalIdentification'] = {}
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          service = described_class.new(user)
          expect { service.submit_combined_fsr(valid_form_data) }
            .to change { DebtsApi::V0::Form5655::VBASubmissionJob.jobs.size }
            .from(0)
            .to(1)
        end
      end
    end

    it 'enqueues a VBA submission job if no selected debts present' do
      valid_form_data['selectedDebtsAndCopays'] = []
      valid_form_data['personalIdentification'] = {}
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          service = described_class.new(user)
          expect { service.submit_combined_fsr(valid_form_data) }
            .to change { DebtsApi::V0::Form5655::VBASubmissionJob.jobs.size }
            .from(0)
            .to(1)
        end
      end
    end

    it 'enqueues a VHA submission job' do
      valid_form_data['selectedDebtsAndCopays'] = [{
        'station' => {
          'facilitYNum' => '123'
        },
        'resolutionOption' => 'waiver',
        'debtType' => 'COPAY'
      }]
      valid_form_data['personalIdentification'] = {}
      service = described_class.new(user)
      expect { service.submit_combined_fsr(valid_form_data) }
        .to change { DebtsApi::V0::Form5655::VHASubmissionJob.jobs.size }
        .from(0)
        .to(1)
    end

    it 'creates a form 5655 submission record' do
      valid_form_data['selectedDebtsAndCopays'] = [{
        'station' => {
          'facilitYNum' => '123'
        },
        'resolutionOption' => 'waiver',
        'debtType' => 'COPAY'
      }]
      valid_form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      service = described_class.new(user)
      expect { service.submit_combined_fsr(valid_form_data) }.to change(Form5655Submission, :count).by(1)
    end
  end

  describe '#create_vha_fsr' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let(:user) { build(:user, :loa3) }

    before do
      valid_form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      response = Faraday::Response.new(status: 200, body:
      {
        message: 'Success'
      })
      allow_any_instance_of(DebtManagementCenter::VBS::Request).to receive(:post).and_return(response)
      mock_sharepoint_upload
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'creates multiple jobs with multiple stations' do
      valid_form_data['selectedDebtsAndCopays'] = [
        {
          'station' => {
            'facilitYNum' => '123'
          },
          'resolutionOption' => 'waiver',
          'debtType' => 'COPAY'
        },
        {
          'station' => {
            'facilitYNum' => '456'
          },
          'resolutionOption' => 'waiver',
          'debtType' => 'COPAY'
        }
      ]
      service = described_class.new(user)
      expect { service.create_vha_fsr(valid_form_data) }
        .to change { DebtsApi::V0::Form5655::VHASubmissionJob.jobs.size }
        .from(0)
        .to(2)
    end
  end

  describe '#send_vha_confirmation_email' do
    it 'creates a va notify job' do
      email = 'foo@bar.com'
      email_personalization_info = {
        'name' => 'Joe',
        'time' => '48 hours',
        'date' => Time.zone.now.strftime('%m/%d/%Y')
      }
      service = described_class.new
      expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
        email,
        described_class::VHA_CONFIRMATION_TEMPLATE,
        email_personalization_info
      )
      service.send_vha_confirmation_email('ok',
                                          { 'email' => email,
                                            'email_personalization_info' => email_personalization_info })
    end
  end
end
