# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/financial_status_report_service'
require 'debt_management_center/sidekiq/va_notify_email_job'
require 'debt_management_center/sharepoint/request'
require 'support/financial_status_report_helpers'

RSpec.describe DebtManagementCenter::FinancialStatusReportService, type: :service do
  before do
    mock_pdf_fill
  end

  it 'inherits SentryLogging' do
    expect(described_class.ancestors).to include(SentryLogging)
  end

  def mock_pdf_fill
    pdf_stub = class_double('PdfFill::Filler').as_stubbed_const
    allow(pdf_stub).to receive(:fill_ancillary_form).and_return(::Rails.root.join(
      *'/spec/fixtures/dmc/5655.pdf'.split('/')
    ).to_s)
  end

  describe '#submit_financial_status_report' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
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
              File.read(
                Rails.root.join('spec', 'fixtures', 'dmc', '5655.pdf')
              ).force_encoding('ASCII-8BIT')
            )
          end
        end
      end
    end
  end

  describe '#submit_vba_fsr' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
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
            res = subject.submit_vba_fsr(valid_form_data)
            expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
          end
        end
      end
    end
  end

  describe '#submit_vha_fsr' do
    let(:form_submission) { build(:form5655_submission) }
    let(:user) { build(:user, :loa3) }
    let(:user_data) { build(:user_profile_attributes) }
    let(:mpi_profile) { build(:mpi_profile, family_name: 'Beer', ssn: '123456598') }
    let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:file_path) { ::Rails.root.join(*'/spec/fixtures/dmc/5655.pdf'.split('/')).to_s }

    before do
      upload_time = DateTime.new(2023, 8, 29, 16, 13, 22)
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(file_path)
      allow(File).to receive(:delete).and_return(nil)
      allow(DateTime).to receive(:now).and_return(upload_time)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
    end

    it 'submits to the VBS endpoint' do
      service = described_class.new(user_data)
      VCR.use_cassette('vha/sharepoint/authenticate') do
        VCR.use_cassette('vha/sharepoint/upload_pdf') do
          VCR.use_cassette('dmc/submit_to_vbs') do
            expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
          end
        end
      end
    end

    it 'parses out delimiter characters' do
      VCR.use_cassette('vha/sharepoint/authenticate') do
        VCR.use_cassette('vha/sharepoint/upload_pdf') do
          service = described_class.new(user_data)
          delimitered_json = { 'name' => "^Gr\neg|" }
          parsed_form_string = service.send(:remove_form_delimiters, delimitered_json).to_s
          expect(['^', '|', "\n"].any? { |i| parsed_form_string.include? i }).to be false
        end
      end
    end

    context 'with streamlined waiver' do
      let(:form_submission) { build(:sw_form5655_submission) }
      let(:non_streamlined_form_submission) { build(:non_sw_form5655_submission) }

      it 'submits to the VBS endpoint' do
        VCR.use_cassette('vha/sharepoint/authenticate') do
          VCR.use_cassette('vha/sharepoint/upload_pdf') do
            VCR.use_cassette('dmc/submit_to_vbs') do
              service = described_class.new(user_data)
              expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
            end
          end
        end
      end

      it 'makes streamlined the last key in the form hash' do
        VCR.use_cassette('vha/sharepoint/authenticate') do
          VCR.use_cassette('vha/sharepoint/upload_pdf') do
            service = described_class.new(user_data)
            adjusted_form = service.send(:streamline_adjustments, form_submission.form)
            expect(adjusted_form.keys.last).to eq('streamlined')
          end
        end
      end

      it 'changes fsrReason for streamlined waivers' do
        VCR.use_cassette('vha/sharepoint/authenticate') do
          VCR.use_cassette('vha/sharepoint/upload_pdf') do
            service = described_class.new(user_data)
            adjusted_form = service.send(:streamline_adjustments, form_submission.form)
            expect(adjusted_form['personalIdentification']['fsrReason']).to eq('et, Automatically Approved')
          end
        end
      end

      it 'does not change fsrReason for non-streamlined waivers' do
        VCR.use_cassette('vha/sharepoint/authenticate') do
          VCR.use_cassette('vha/sharepoint/upload_pdf') do
            service = described_class.new(user_data)
            adjusted_form = service.send(:streamline_adjustments, non_streamlined_form_submission.form)
            expect(adjusted_form['personalIdentification']['fsrReason']).not_to eq('Automatically Approved')
          end
        end
      end
    end
  end

  describe '#submit_combined_fsr' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let!(:user) { build(:user, :loa3) }

    before do
      valid_form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'enqueues a VBA submission job' do
      valid_form_data['selectedDebtsAndCopays'] = [{ 'foo' => 'bar', 'debtType' => 'DEBT' }]
      valid_form_data['personalIdentification'] = {}
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          service = described_class.new(user)
          expect { service.submit_combined_fsr(valid_form_data) }
            .to change { Form5655::VBASubmissionJob.jobs.size }
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
            .to change { Form5655::VBASubmissionJob.jobs.size }
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
        .to change { Form5655::VHASubmissionJob.jobs.size }
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
      expect(Form5655Submission.last.in_progress?).to eq(true)
    end
  end

  describe '#create_vha_fsr' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let(:user) { build(:user, :loa3) }

    before do
      valid_form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
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
        .to change { Form5655::VHASubmissionJob.jobs.size }
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
      template_id = described_class::VHA_CONFIRMATION_TEMPLATE
      service = described_class.new
      expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
        email,
        template_id,
        email_personalization_info
      )
      service.send_vha_confirmation_email('ok',
                                          { 'email' => email,
                                            'email_personalization_info' => email_personalization_info,
                                            'template_id' => template_id })
    end
  end
end
