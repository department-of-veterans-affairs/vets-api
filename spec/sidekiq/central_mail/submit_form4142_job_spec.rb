# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission

RSpec.describe CentralMail::SubmitForm4142Job, type: :job do
  subject { described_class }

  # Use existing fixture simple.pdf as test input
  let(:fixture_pdf) { Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-4142', 'simple.pdf') }
  let(:test_pdf) { Rails.root.join('tmp', 'test_output.pdf') }

  before do
    Sidekiq::Job.clear_all
    # Make Job use old CentralMail route for all tests
    allow(Flipper).to receive(:enabled?).with(:disability_compensation_form4142_supplemental).and_return(false)
    # By default, features are enabled in test environments and disabled by default in other environments
    # This is to ensure that the 2024 4142 template is
    # not used in tests unless explicitly enabled
    allow(Flipper).to receive(:enabled?).with(:disability_526_form4142_validate_schema).and_return(false)

    # Stub out pdf methods as they are not needed for these tests and are cpu expensive
    FileUtils.cp(fixture_pdf, test_pdf)
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Form4142Processor).to receive(:fill_form_template)
      .and_return(test_pdf.to_s)
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Form4142Processor).to receive(:add_signature_stamp)
      .and_return(test_pdf.to_s)
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Form4142Processor).to receive(:add_vagov_timestamp)
      .and_return(test_pdf.to_s)
    allow_any_instance_of(EVSS::DisabilityCompensationForm::Form4142Processor).to receive(:submission_date_stamp)
      .and_return(test_pdf.to_s)
  end

  # Clean up the test output file
  after { FileUtils.rm_f(test_pdf) }

  #######################
  ## CentralMail Route ##
  #######################

  describe 'Test old CentralMail route' do
    before do
      # Make Job use old CentralMail route for all tests
      Flipper.disable(:disability_compensation_form4142_supplemental) # rubocop:disable Project/ForbidFlipperToggleInSpecs
    end

    let(:user_account) { user.user_account }
    let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
    let(:auth_headers) do
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    end
    let(:evss_claim_id) { 123_456_789 }
    let(:saved_claim) { create(:va526ez) }

    describe '.perform_async' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end
      let(:submission) do
        Form526Submission.create(user_uuid: user.uuid,
                                 user_account:,
                                 auth_headers_json: auth_headers.to_json,
                                 saved_claim_id: saved_claim.id,
                                 form_json:,
                                 submitted_claim_id: evss_claim_id)
      end
      let(:metadata_hash) do
        form4142 = submission.form[Form526Submission::FORM_4142]
        form4142['veteranFullName'].update('first' => "Bey'oncé", 'last' => 'Knowle$-Carter')
        form4142['veteranAddress'].update('postalCode' => '123456789')
        subject.perform_async(submission.id)
        jid = subject.jobs.last['jid']
        processor = EVSS::DisabilityCompensationForm::Form4142Processor.new(submission, jid)
        request_body = processor.request_body
        JSON.parse(request_body['metadata'])
      end

      context 'with a successful submission job' do
        it 'queues a job for submit' do
          expect do
            subject.perform_async(submission.id)
          end.to change(subject.jobs, :size).by(1)
        end

        it 'submits successfully' do
          VCR.use_cassette('central_mail/submit_4142') do
            subject.perform_async(submission.id)
            jid = subject.jobs.last['jid']
            described_class.drain
            expect(jid).not_to be_empty
          end
        end

        it 'uses proper submission creation date for the received date' do
          received_date = metadata_hash['receiveDt']
          # Form4142Processor should use Central Time Zone
          # See https://dsva.slack.com/archives/C053U7BUT27/p1706808933985779?thread_ts=1706727152.783229&cid=C053U7BUT27
          expect(
            submission.created_at.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d %H:%M:%S')
          ).to eq(received_date)
        end

        it 'corrects for invalid characters in generated metadata' do
          veteran_first_name = metadata_hash['veteranFirstName']
          veteran_last_name = metadata_hash['veteranLastName']
          allowed_chars_regex = %r{^[a-zA-Z/\-\s]}
          expect(veteran_first_name).to match(allowed_chars_regex)
          expect(veteran_last_name).to match(allowed_chars_regex)
        end

        it 'reformats zip code in generated metadata' do
          zip_code = metadata_hash['zipCode']
          expected_zip_format = /\A[0-9]{5}(?:-[0-9]{4})?\z/
          expect(zip_code).to match(expected_zip_format)
        end
      end

      context 'with a submission timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        end

        it 'raises a gateway timeout error' do
          subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with an unexpected error' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
        end

        it 'raises a standard error' do
          subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(StandardError)
        end
      end
    end

    describe '.perform_async for client error' do
      let(:missing_postalcode_form_json) do
        File.read 'spec/support/disability_compensation_form/submissions/with_4142_missing_postalcode.json'
      end
      let(:submission) do
        Form526Submission.create(user_uuid: user.uuid,
                                 user_account:,
                                 auth_headers_json: auth_headers.to_json,
                                 saved_claim_id: saved_claim.id,
                                 form_json: missing_postalcode_form_json,
                                 submitted_claim_id: evss_claim_id)
      end

      context 'with a client error' do
        it 'raises a central mail response error' do
          VCR.use_cassette('central_mail/submit_4142_400') do
            subject.perform_async(submission.id)
            expect { described_class.drain }.to raise_error(CentralMail::SubmitForm4142Job::CentralMailResponseError)
          end
        end
      end
    end

    context 'catastrophic failure state' do
      describe 'when all retries are exhausted' do
        let!(:form526_submission) { create(:form526_submission, user_account:) }
        let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }

        it 'updates a StatsD counter and updates the status on an exhaustion event' do
          # We are also incrementing a metric when the Form4142DocumentUploadFailureEmail job runs
          allow(StatsD).to receive(:increment)

          subject.within_sidekiq_retries_exhausted_block({ 'jid' => form526_job_status.job_id }) do
            expect(StatsD).to receive(:increment).with("#{subject::CENTRAL_MAIL_STATSD_KEY_PREFIX}.exhausted")
            expect(Rails).to receive(:logger).and_call_original
          end
          form526_job_status.reload
          expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
        end

        describe 'when an error occurs during exhaustion handling and FailureEmail fails to enqueue' do
          let!(:zsf_tag) { Form526Submission::ZSF_DD_TAG_SERVICE }
          let!(:zsf_monitor) { ZeroSilentFailures::Monitor.new(zsf_tag) }
          let!(:failure_email) { EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail }

          before do
            Flipper.enable(:form526_send_4142_failure_notification) # rubocop:disable Project/ForbidFlipperToggleInSpecs
            allow(ZeroSilentFailures::Monitor).to receive(:new).with(zsf_tag).and_return(zsf_monitor)
          end

          it 'logs a silent failure' do
            expect(zsf_monitor).to receive(:log_silent_failure).with(
              {
                job_id: form526_job_status.job_id,
                error_class: nil,
                error_message: 'An error occurred',
                timestamp: instance_of(Time),
                form526_submission_id: form526_submission.id
              },
              user_account.id,
              call_location: instance_of(Logging::CallLocation)
            )

            args = { 'jid' => form526_job_status.job_id, 'args' => [form526_submission.id] }

            expect do
              subject.within_sidekiq_retries_exhausted_block(args) do
                allow(failure_email).to receive(:perform_async).and_raise(StandardError, 'Simulated error')
              end
            end.to raise_error(StandardError, 'Simulated error')
          end
        end
      end
    end

    # End of the Old CentralMail Route tests
  end

  ######################
  ## Lighthouse Route ##
  ######################

  describe 'Test new Lighthouse route' do
    before do
      # Make Job use new Lighthouse route for all tests
      allow(Flipper).to receive(:enabled?).with(:disability_compensation_form4142_supplemental).and_return(true)
    end

    let(:user_account) { user.user_account }
    let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
    let(:auth_headers) do
      EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    end
    let(:evss_claim_id) { 123_456_789 }
    let(:saved_claim) { create(:va526ez) }

    describe '.perform_async' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end
      let(:submission) do
        Form526Submission.create(user_uuid: user.uuid,
                                 user_account:,
                                 auth_headers_json: auth_headers.to_json,
                                 saved_claim_id: saved_claim.id,
                                 form_json:,
                                 submitted_claim_id: evss_claim_id)
      end
      let(:metadata_hash) do
        form4142 = submission.form[Form526Submission::FORM_4142]
        form4142['veteranFullName'].update('first' => "Bey'oncé", 'last' => 'Knowle$-Carter')
        form4142['veteranAddress'].update('postalCode' => '123456789')
        subject.perform_async(submission.id)
        jid = subject.jobs.last['jid']
        processor = EVSS::DisabilityCompensationForm::Form4142Processor.new(submission, jid)
        request_body = processor.request_body
        JSON.parse(request_body['metadata'])
      end

      context 'with a successful submission job' do
        it 'queues a job for submit' do
          expect do
            subject.perform_async(submission.id)
          end.to change(subject.jobs, :size).by(1)
        end

        it 'Creates a form 4142 submission polling record, when enabled' do
          Flipper.enable(CentralMail::SubmitForm4142Job::POLLING_FLIPPER_KEY) # rubocop:disable Project/ForbidFlipperToggleInSpecs
          expect do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                subject.perform_async(submission.id)
                described_class.drain
              end
            end
          end.to change(FormSubmission, :count).by(1)
                                               .and change(FormSubmissionAttempt, :count).by(1)
          fs_record = FormSubmission.last
          fs_attempt_record = FormSubmissionAttempt.last
          expect(Form526Submission.find_by(saved_claim_id: fs_record.saved_claim_id).id).to eq(submission.id)
          expect(fs_attempt_record.pending?).to be(true)
        end

        it 'Returns successfully after creating polling record' do
          Flipper.enable(CentralMail::SubmitForm4142Job::POLLING_FLIPPER_KEY) # rubocop:disable Project/ForbidFlipperToggleInSpecs
          Sidekiq::Testing.inline! do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                allow_any_instance_of(SemanticLogger::Logger).to receive(:info).and_return(true)
                jid = subject.perform_async(submission.id)
                subject.drain
                job_status_record = submission.form526_job_statuses.find_by(job_id: jid)
                Rails.logger.level
                expect(job_status_record).not_to be_nil
                expect(job_status_record.job_class).to eq('SubmitForm4142Job')
                expect(job_status_record.status).to eq('success')
              end
            end
          end
        end

        it 'Does not create a form 4142 submission polling record, when disabled' do
          Flipper.disable(CentralMail::SubmitForm4142Job::POLLING_FLIPPER_KEY) # rubocop:disable Project/ForbidFlipperToggleInSpecs
          expect do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
              VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
                subject.perform_async(submission.id)
                described_class.drain
              end
            end
          end.to not_change(FormSubmission, :count)
            .and not_change(FormSubmissionAttempt, :count)
        end

        it 'submits successfully' do
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload_location') do
            VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
              subject.perform_async(submission.id)
              jid = subject.jobs.last['jid']
              described_class.drain
              expect(jid).not_to be_empty
            end
          end
        end

        it 'uses proper submission creation date for the received date' do
          received_date = metadata_hash['receiveDt']
          # Form4142Processor should use Central Time Zone
          # See https://dsva.slack.com/archives/C053U7BUT27/p1706808933985779?thread_ts=1706727152.783229&cid=C053U7BUT27
          expect(
            submission.created_at.in_time_zone('Central Time (US & Canada)').strftime('%Y-%m-%d %H:%M:%S')
          ).to eq(received_date)
        end

        it 'corrects for invalid characters in generated metadata' do
          veteran_first_name = metadata_hash['veteranFirstName']
          veteran_last_name = metadata_hash['veteranLastName']
          allowed_chars_regex = %r{^[a-zA-Z/\-\s]}
          expect(veteran_first_name).to match(allowed_chars_regex)
          expect(veteran_last_name).to match(allowed_chars_regex)
        end

        it 'reformats zip code in generated metadata' do
          zip_code = metadata_hash['zipCode']
          expected_zip_format = /\A[0-9]{5}(?:-[0-9]{4})?\z/
          expect(zip_code).to match(expected_zip_format)
        end
      end

      context 'with a submission timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        end

        it 'raises a gateway timeout error' do
          subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with an unexpected error' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
        end

        it 'raises a standard error' do
          subject.perform_async(submission.id)
          expect { described_class.drain }.to raise_error(StandardError)
        end
      end
    end

    describe '.perform_async for client error' do
      let(:missing_postalcode_form_json) do
        File.read 'spec/support/disability_compensation_form/submissions/with_4142_missing_postalcode.json'
      end
      let(:submission) do
        Form526Submission.create(user_uuid: user.uuid,
                                 user_account:,
                                 auth_headers_json: auth_headers.to_json,
                                 saved_claim_id: saved_claim.id,
                                 form_json: missing_postalcode_form_json,
                                 submitted_claim_id: evss_claim_id)
      end

      context 'with a client error' do
        it 'raises a central mail response error' do
          skip 'The VCR cassette needs to be changed to contain Lighthouse specific data.'
          VCR.use_cassette('lighthouse/benefits_intake/200_lighthouse_intake_upload') do
            subject.perform_async(submission.id)
            expect { described_class.drain }.to raise_error(CentralMail::SubmitForm4142Job::CentralMailResponseError)
          end
        end
      end
    end

    context 'catastrophic failure state' do
      describe 'when all retries are exhausted' do
        let!(:form526_submission) { create(:form526_submission) }
        let!(:form526_job_status) { create(:form526_job_status, :retryable_error, form526_submission:, job_id: 1) }

        it 'updates a StatsD counter and updates the status on an exhaustion event' do
          # We are also incrementing a metric when the Form4142DocumentUploadFailureEmail job runs
          allow(StatsD).to receive(:increment)

          subject.within_sidekiq_retries_exhausted_block({ 'jid' => form526_job_status.job_id }) do
            expect(StatsD).to receive(:increment).with("#{subject::LIGHTHOUSE_STATSD_KEY_PREFIX}.exhausted")
            expect(Rails).to receive(:logger).and_call_original
          end
          form526_job_status.reload
          expect(form526_job_status.status).to eq(Form526JobStatus::STATUS[:exhausted])
        end

        context 'when the form526_send_4142_failure_notification Flipper is enabled' do
          before do
            Flipper.enable(:form526_send_4142_failure_notification)  # rubocop:disable Project/ForbidFlipperToggleInSpecs
          end

          it 'enqueues a failure notification mailer to send to the veteran' do
            subject.within_sidekiq_retries_exhausted_block(
              {
                'jid' => form526_job_status.job_id,
                'args' => [form526_submission.id]
              }
            ) do
              expect(EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail)
                .to receive(:perform_async).with(form526_submission.id)
            end
          end
        end

        context 'when the form526_send_4142_failure_notification Flipper is disabled' do
          before do
            Flipper.disable(:form526_send_4142_failure_notification) # rubocop:disable Project/ForbidFlipperToggleInSpecs
          end

          it 'does not enqueue a failure notification mailer to send to the veteran' do
            subject.within_sidekiq_retries_exhausted_block(
              {
                'jid' => form526_job_status.job_id,
                'args' => [form526_submission.id]
              }
            ) do
              expect(EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail)
                .not_to receive(:perform_async)
            end
          end
        end
      end
    end

    # End of the new Lighthouse Route tests
  end

  # End of the overall Spec
end
