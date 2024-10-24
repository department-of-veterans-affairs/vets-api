# frozen_string_literal: true

require 'rails_helper'
require 'debts_api/v0/financial_status_report_service'
require 'debt_management_center/sidekiq/va_notify_email_job'
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
    let(:combined_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/combined_fsr_form') }
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
            expect(service).to receive(:submit_combined_fsr)
            service.submit_financial_status_report(combined_form_data)
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
            expect(service).to receive(:submit_combined_fsr)
            service.submit_financial_status_report(combined_form_data)
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
        allow(Settings).to receive(:vsp_environment).and_return('production')
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
    let(:user_account) { create(:user_account) }
    let(:form_submission) { build(:debts_api_form5655_submission, user_account_id: user_account.id) }
    let(:user_data) { build(:user_profile_attributes) }
    let(:user_info) do
      OpenStruct.new(
        {
          verified_at: '1-1-2022',
          sub: 'some-logingov_uuid',
          social_security_number: '123456789',
          birthdate: '2022-01-01',
          given_name: 'some-name',
          family_name: 'some-family-name',
          email: 'some-email'
        }
      )
    end
    let(:mpi_profile) do
      build(:mpi_profile,
            ssn: user_info.social_security_number,
            birth_date: Formatters::DateFormatter.format_date(user_info.birthdate),
            given_names: [user_info.given_name],
            family_name: user_info.family_name)
    end
    let(:find_profile_response) { create(:find_profile_response, profile: mpi_profile) }

    context 'success' do
      before do
        mock_sharepoint_upload
      end

      it 'submits to the VBS endpoint' do
        service = described_class.new(user_data)
        VCR.use_cassette('dmc/submit_to_vbs') do
          expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
        end
      end

      context 'with streamlined waiver' do
        let(:form_submission) { build(:debts_api_sw_form5655_submission) }
        let(:non_streamlined_form_submission) { build(:debts_api_non_sw_form5655_submission) }

        it 'submits to the VBS endpoint' do
          VCR.use_cassette('dmc/submit_to_vbs') do
            service = described_class.new(user_data)
            expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
          end
        end
      end
    end

    context 'failure' do
      it 'raises an error when submission fails' do
        service = described_class.new(user_data)

        allow_any_instance_of(MPI::Service)
          .to receive(:find_profile_by_identifier).and_return(find_profile_response)
        allow_any_instance_of(DebtManagementCenter::Sharepoint::Request)
          .to receive(:set_sharepoint_access_token).and_return('fake token')

        expect(form_submission).to receive(:register_failure).with(
          a_string_starting_with('FinancialStatusReportService#submit_vha_fsr: BackendServiceException:')
        )

        Timecop.freeze(Time.new(2024, 10, 22).utc) do
          VCR.use_cassette('vha/sharepoint/upload_pdf_400_response') do
            expect do
              service.submit_vha_fsr(form_submission)
            end.to raise_error(Common::Exceptions::BackendServiceException,
                               'BackendServiceException: {:status=>400, :detail=>nil, :code=>"VA900", :source=>nil}')
          end
        end
      end

      it 'raises an error when Faraday fails' do
        service = described_class.new(user_data)

        # Mock the Faraday connection and raise an error
        allow_any_instance_of(Faraday::Connection)
          .to receive(:post).and_raise(StandardError.new('Upload error'))

        expect do
          service.submit_vha_fsr(form_submission)
        end.to raise_error(StandardError, 'Upload error')
      end
    end
  end

  describe '#submit_combined_fsr' do
    let(:valid_form_data) { get_fixture('dmc/fsr_submission') }
    let(:valid_vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }
    let(:vha_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vha_fsr_form') }
    let(:combined_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/combined_fsr_form') }
    let!(:user) { build(:user, :loa3) }

    before do
      valid_form_data.deep_transform_keys! { |key| key.to_s.camelize(:lower) }
      mock_sharepoint_upload
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'enqueues a VBA submission job' do
      VCR.use_cassette('dmc/submit_fsr') do
        VCR.use_cassette('bgs/people_service/person_data') do
          service = described_class.new(user)
          builder = DebtsApi::V0::FsrFormBuilder.new(valid_vba_form_data, '', user)
          expect { service.submit_combined_fsr(builder) }
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
          builder = DebtsApi::V0::FsrFormBuilder.new(valid_form_data, '', user)
          expect { service.submit_combined_fsr(builder) }
            .to change { DebtsApi::V0::Form5655::VBASubmissionJob.jobs.size }
            .from(0)
            .to(1)
        end
      end
    end

    it 'enqueues VHA submission jobs' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(vha_form_data, '', user)
      copay_count = builder.vha_forms.length
      expect { service.submit_combined_fsr(builder) }
        .to change { DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs.size }
        .from(0)
        .to(copay_count)
        .and change { DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs.size }
        .from(0)
        .to(copay_count)
    end

    it 'creates a form 5655 submission record' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(vha_form_data, '', user)
      copay_count = builder.vha_forms.length
      expect { service.submit_combined_fsr(builder) }.to change(
        DebtsApi::V0::Form5655Submission, :count
      ).by(copay_count)
      expect(DebtsApi::V0::Form5655Submission.last.in_progress?).to eq(true)
      form = service.send(:add_vha_specific_data, DebtsApi::V0::Form5655Submission.last)
      expect(form.class).to be(Hash)
    end

    context 'with both debts and copays' do
      it 'adds combined key to forms' do
        service = described_class.new(user)
        builder = DebtsApi::V0::FsrFormBuilder.new(combined_form_data, '', user)
        copay_count = builder.vha_forms.length
        debt_count = builder.vba_form.present? ? 1 : 0
        needed_count = copay_count + debt_count
        expect do
          service.submit_combined_fsr(builder)
        end.to change(DebtsApi::V0::Form5655Submission, :count).by(needed_count)
        expect(DebtsApi::V0::Form5655Submission.last.public_metadata['combined']).to eq(true)
        debt_amounts = DebtsApi::V0::Form5655Submission.with_debt_type('DEBT').last.public_metadata['debt_amounts']
        expect(debt_amounts).to eq(['541.67', '1134.22'])
      end
    end
  end

  describe '#create_vba_fsr' do
    let(:valid_vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }
    let(:valid_vha_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vha_fsr_form') }
    let(:user) { build(:user, :loa3) }

    before do
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'persists vba FSRs' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vba_form_data, '', user)
      expect { service.create_vba_fsr(builder) }.to change(DebtsApi::V0::Form5655Submission, :count).by(1)
    end

    it 'gracefully handles a lack of vba FSRs' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vha_form_data, '', user)
      expect { service.create_vba_fsr(builder) }.not_to change(DebtsApi::V0::Form5655Submission, :count)
    end
  end

  describe '#create_vha_fsr' do
    let(:valid_vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }
    let(:valid_vha_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vha_fsr_form') }
    let(:user) { build(:user, :loa3) }

    before do
      mock_sharepoint_upload
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'creates multiple jobs with multiple stations' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vha_form_data, '', user)
      expect { service.create_vha_fsr(builder) }
        .to change { DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs.size }
        .from(0)
        .to(2)
        .and change { DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs.size }
        .from(0)
        .to(2)
    end

    it 'gracefully handles a lack of vha FSRs' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vba_form_data, '', user)
      expect { service.create_vha_fsr(builder) }.not_to(change do
                                                          DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs.size
                                                        end)
      expect { service.create_vha_fsr(builder) }.not_to(change do
                                                          DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs.size
                                                        end)
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
