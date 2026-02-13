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

  it 'inherits Vets::SharedLogging' do
    expect(described_class.ancestors).to include(Vets::SharedLogging)
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
    let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }
    let(:user_data) { build(:user_profile_attributes) }

    context 'The :combined_financial_status_report flipper is turned on' do
      before do
        allow(Flipper).to receive(:enabled?).with(:combined_financial_status_report).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(false)
      end

      it 'submits combined fsr' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).not_to receive(:perform_in)
            expect(service).to receive(:submit_combined_fsr)
            service.submit_financial_status_report(combined_form_data)
          end
        end
      end
    end

    context 'The :combined_financial_status_report flipper is turned off' do
      before do
        allow(Flipper).to receive(:enabled?).with(:combined_financial_status_report).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(false)
      end

      it 'ignores flipper and uses combined fsr' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).not_to receive(:perform_in)
            expect(service).to receive(:submit_combined_fsr)
            service.submit_financial_status_report(combined_form_data)
          end
        end
      end
    end

    context 'The :fsr_zero_silent_errors_in_progress_email flipper is turned on' do
      before do
        allow(Flipper).to receive(:enabled?).with(:combined_financial_status_report).and_return(false)
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(true)
      end

      it 'fires the confirmation email with cache_key instead of user info' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user)
            allow(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key')

            expect(Sidekiq::AttrPackage).to receive(:create).with(
              email: user.email,
              first_name: user.first_name
            ).and_return('test_cache_key')

            expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).to receive(:perform_in).with(
              5.minutes,
              hash_including(
                'submission_type' => 'fsr',
                'cache_key' => 'test_cache_key',
                'template_id' => 'fake_template_id',
                'user_uuid' => user.uuid
              )
            )
            expect(DebtsApi::V0::Form5655::SendConfirmationEmailJob).not_to receive(:perform_in).with(
              anything,
              hash_including('email' => user.email)
            )
            expect(service).to receive(:submit_combined_fsr)
            service.submit_financial_status_report(combined_form_data)
          end
        end
      end

      it 'raises when AttrPackage.create fails' do
        VCR.use_cassette('bgs/people_service/person_data') do
          service = described_class.new(user)
          allow(Sidekiq::AttrPackage).to receive(:create).and_raise(
            Sidekiq::AttrPackageError.new('create', 'Redis connection failed')
          )

          expect { service.submit_financial_status_report(combined_form_data) }.to raise_error(Sidekiq::AttrPackageError)
        end
      end
    end
  end

  describe '#get_pdf' do
    let(:filenet_id) { 'ABCD-1234' }
    let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }

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
    let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }
    let(:user_data) { build(:user_profile_attributes) }
    let(:malformed_form_data) do
      { 'bad' => 'data' }
    end
    let(:mock_success_response) { double('FaradayResponse', status: 201, success?: true, body: valid_form_data) }

    context 'with valid form data' do
      before do
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(false)
      end

      it 'accepts the submission' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            res = service.submit_vba_fsr(valid_form_data)
            expect(res[:status]).to eq('Document created successfully and uploaded to File Net.')
          end
        end
      end

      it 'sends a confirmation email with cache_key instead of user info' do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key')

        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)

            expect(Sidekiq::AttrPackage).to receive(:create).with(
              email: user_data.email.downcase,
              personalisation: {
                'name' => user_data.first_name,
                'time' => '48 hours',
                'date' => Time.zone.now.strftime('%m/%d/%Y')
              }
            ).and_return('test_cache_key')

            expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
              nil,
              described_class::VBA_CONFIRMATION_TEMPLATE,
              nil,
              { id_type: 'email', cache_key: 'test_cache_key' }
            )
            service.submit_vba_fsr(valid_form_data)
          end
        end
      end

      it 'does not send a confirmation email' do
        allow(Settings).to receive(:vsp_environment).and_return('production')
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(true)
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            expect(DebtManagementCenter::VANotifyEmailJob).not_to receive(:perform_async)
            service.submit_vba_fsr(valid_form_data)
          end
        end
      end

      it 'measures latency of the API call using measure_latency' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            expect(service).to receive(:measure_latency)
              .with("#{described_class::STATSD_KEY_PREFIX}.fsr.submit.vba.latency")
              .and_call_original

            service.submit_vba_fsr(valid_form_data)
          end
        end
      end

      it 'calls perform inside measure_latency' do
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            service = described_class.new(user_data)
            expect(service).to receive(:measure_latency).and_yield
            expect(service).to receive(:perform).with(:post, 'financial-status-report/formtopdf',
                                                      hash_including(valid_form_data)).and_return(mock_success_response)

            service.submit_vba_fsr(valid_form_data)
          end
        end
      end

      it 'logs submission attempt' do
        service = described_class.new(user_data)
        VCR.use_cassette('dmc/submit_fsr') do
          VCR.use_cassette('bgs/people_service/person_data') do
            expect(Rails.logger).to receive(:info).with(
              '5655 Form Submitting to VBA'
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
        expect_any_instance_of(Vets::SharedLogging).to receive(:log_exception_to_rails).with(
          an_instance_of(ActiveModel::ValidationError)
        )
      end

      it 'logs to rails' do
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
    let(:form_submission) do
      build(:debts_api_form5655_submission, user_account_id: user_account.id, created_at: Time.current)
    end
    let(:user_data) { build(:user_profile_attributes) }
    let(:user_info) do
      OpenStruct.new(
        {
          verified_at: '1-1-2022',
          sub: 'some-logingov_uuid',
          social_security_number: '123456598',
          birthdate: '2022-01-01',
          given_name: 'some-name',
          family_name: 'Beer',
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
        allow_any_instance_of(DebtsApi::V0::FinancialStatusReportService).to receive(:measure_latency).and_yield
      end

      it 'submits to the VBS endpoint' do
        service = described_class.new(user_data)
        VCR.use_cassette('dmc/submit_to_vbs') do
          expect(service.submit_vha_fsr(form_submission)).to eq({ status: 200 })
        end
      end

      it 'measures latency of the API call using measure_latency' do
        service = described_class.new(user_data)
        VCR.use_cassette('dmc/submit_to_vbs') do
          expect(service).to receive(:measure_latency)
            .with("#{described_class::STATSD_KEY_PREFIX}.fsr.submit.vha.latency")
            .and_yield

          service.submit_vha_fsr(form_submission)
        end
      end

      it 'logs submission attempt' do
        service = described_class.new(user_data)
        VCR.use_cassette('dmc/submit_to_vbs') do
          expect(Rails.logger).to receive(:info).with(
            '5655 Form Submitting to VHA',
            submission_id: form_submission.id
          )

          service.submit_vha_fsr(form_submission)
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
      before do
        allow(Flipper).to receive(:enabled?).with(:debts_sharepoint_error_logging).and_return(false)
      end

      it 'raises an error when submission fails' do
        service = described_class.new(user_data)

        allow_any_instance_of(MPI::Service)
          .to receive(:find_profile_by_identifier).and_return(find_profile_response)
        allow_any_instance_of(DebtManagementCenter::Sharepoint::Request)
          .to receive(:set_sharepoint_access_token).and_return('fake token')

        expect(form_submission).to receive(:register_failure).with(
          a_string_starting_with('FinancialStatusReportService#submit_vha_fsr: BackendServiceException:')
        )

        Timecop.freeze(Time.new(2023, 8, 29, 16, 13, 22).utc) do
          VCR.use_cassette('vha/sharepoint/upload_pdf_400_response', allow_playback_repeats: true) do
            expect do
              service.submit_vha_fsr(form_submission)
            end.to raise_error(Common::Exceptions::BackendServiceException,
                               'BackendServiceException: {:status=>400, :detail=>nil, :code=>"VA900", :source=>nil}')
          end
        end
      end

      context 'with Sharepoint Error Flipper enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:debts_sharepoint_error_logging).and_return(true)
        end

        it 'raises an error when submission fails' do
          service = described_class.new(user_data)

          allow_any_instance_of(MPI::Service)
            .to receive(:find_profile_by_identifier).and_return(find_profile_response)
          allow_any_instance_of(DebtManagementCenter::Sharepoint::Request)
            .to receive(:set_sharepoint_access_token).and_return('fake token')

          expect(form_submission).to receive(:register_failure).with(
            a_string_starting_with('FinancialStatusReportService#submit_vha_fsr: BackendServiceException:')
          )

          Timecop.freeze(Time.new(2023, 8, 29, 16, 13, 22).utc) do
            VCR.use_cassette('vha/sharepoint/upload_pdf_400_response', allow_playback_repeats: true) do
              expect { service.submit_vha_fsr(form_submission) }
                .to raise_error(Common::Exceptions::BackendServiceException) do |e|
                  error_details = e.errors.first
                  expect(error_details.status).to eq('400')
                  expect(error_details.detail).to eq('Malformed PDF request to SharePoint')
                  expect(error_details.code).to eq('SHAREPOINT_PDF_400')
                  expect(error_details.source).to eq('SharepointRequest')
              end
            end
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
    let!(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }

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

    it 'enqueues VHA submission jobs when financial_management_vbs_only is disabled' do
      allow(Flipper).to receive(:enabled?).with(:financial_management_vbs_only).and_return(false)
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

    it 'enqueues only VBSSubmissionJobs when financial_management_vbs_only is enabled' do
      allow(Flipper).to receive(:enabled?).with(:financial_management_vbs_only).and_return(true)
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(vha_form_data, '', user)
      copay_count = builder.vha_forms.length

      expect { service.submit_combined_fsr(builder) }
        .to change { DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs.size }.from(0).to(copay_count)

      expect { service.submit_combined_fsr(builder) }
        .not_to(change { DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs.size })
    end

    it 'creates a form 5655 submission record' do
      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(vha_form_data, '', user)
      copay_count = builder.vha_forms.length
      expect { service.submit_combined_fsr(builder) }.to change(
        DebtsApi::V0::Form5655Submission, :count
      ).by(copay_count)
      expect(DebtsApi::V0::Form5655Submission.last.in_progress?).to be(true)
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
        expect(DebtsApi::V0::Form5655Submission.last.public_metadata['combined']).to be(true)
        debt_amounts = DebtsApi::V0::Form5655Submission.with_debt_type('DEBT').last.public_metadata['debt_amounts']
        expect(debt_amounts).to eq(['541.67', '1134.22'])
      end
    end
  end

  describe '#create_vba_fsr' do
    let(:valid_vba_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vba_fsr_form') }
    let(:valid_vha_form_data) { get_fixture_absolute('modules/debts_api/spec/fixtures/fsr_forms/vha_fsr_form') }
    let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }

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
    let(:user) { build(:user, :loa3, :with_terms_of_use_agreement) }

    before do
      mock_sharepoint_upload
      allow(User).to receive(:find).with(user.uuid).and_return(user)
    end

    it 'creates multiple jobs with multiple stations when financial_management_vbs_only is disabled' do
      allow(Flipper).to receive(:enabled?).with(:financial_management_vbs_only).and_return(false)

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

    it 'creates only VBSSubmissionJobs when financial_management_vbs_only is enabled' do
      allow(Flipper).to receive(:enabled?).with(:financial_management_vbs_only).and_return(true)

      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vha_form_data, '', user)

      expect { service.create_vha_fsr(builder) }
        .to change { DebtsApi::V0::Form5655::VHA::VBSSubmissionJob.jobs.size }
        .from(0).to(2)
        .and(not_change { DebtsApi::V0::Form5655::VHA::SharepointSubmissionJob.jobs.size })
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

    it 'increments StatsD' do
      allow(StatsD).to receive(:increment)

      expect(StatsD).to receive(:increment).with(
        "#{DebtsApi::V0::Form5655::VHA::VBSSubmissionJob::STATS_KEY}.initiated"
      )

      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vha_form_data, '', user)
      service.create_vha_fsr(builder)
    end

    it 'passes cache_key in batch callback options instead of user info' do
      allow(StatsD).to receive(:increment)
      allow(Sidekiq::AttrPackage).to receive(:create).and_return('test_cache_key')

      service = described_class.new(user)
      builder = DebtsApi::V0::FsrFormBuilder.new(valid_vha_form_data, '', user)

      batch_double = instance_double(Sidekiq::Batch)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
      allow(batch_double).to receive(:jobs).and_yield

      expect(Sidekiq::AttrPackage).to receive(:create).with(
        email: user.email&.downcase,
        personalisation: {
          'name' => user.first_name,
          'time' => '48 hours',
          'date' => Time.zone.now.strftime('%m/%d/%Y')
        }
      ).and_return('test_cache_key')

      expect(batch_double).to receive(:on).with(
        :success,
        'DebtsApi::V0::FinancialStatusReportService#send_vha_confirmation_email',
        hash_including('cache_key' => 'test_cache_key', 'template_id' => anything)
      )
      expect(batch_double).not_to receive(:on).with(
        anything,
        anything,
        hash_including('email' => anything)
      )

      service.create_vha_fsr(builder)
    end
  end

  describe '#send_vha_confirmation_email' do
    context 'fsr_zero_silent_errors_in_progress_email is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(false)
      end

      it 'creates a va notify job with cache_key instead of user info' do
        service = described_class.new
        expect(DebtManagementCenter::VANotifyEmailJob).to receive(:perform_async).with(
          nil,
          'template_123',
          nil,
          { id_type: 'email', failure_mailer: false, cache_key: 'test_cache_key' }
        )
        service.send_vha_confirmation_email('ok',
                                            { 'cache_key' => 'test_cache_key',
                                              'template_id' => 'template_123' })
      end
    end

    context 'fsr_zero_silent_errors_in_progress_email is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:fsr_zero_silent_errors_in_progress_email).and_return(true)
      end

      it 'does not create a va notify job' do
        service = described_class.new
        expect(DebtManagementCenter::VANotifyEmailJob).not_to receive(:perform_async)
        service.send_vha_confirmation_email('ok',
                                            { 'cache_key' => 'test_cache_key',
                                              'template_id' => 'template_123' })
      end
    end
  end
end
