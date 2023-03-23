# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526Submission do
  subject do
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers_json: auth_headers.to_json,
      form_json:
    )
  end

  let(:user) { create(:user, :loa3, first_name: 'Beyonce', last_name: 'Knowles') }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:form_json) do
    File.read('spec/support/disability_compensation_form/submissions/only_526.json')
  end

  shared_examples '#start_evss_submission' do
    context 'when it is all claims' do
      it 'queues an all claims job' do
        expect do
          subject.start_evss_submission_job
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(1)
      end
    end
  end

  describe '#start' do
    context 'the submission is for hypertension' do
      let(:hypertension_form_json) do
        File.read('spec/support/disability_compensation_form/submissions/only_526_hypertension.json')
      end
      let(:form_for_hypertension) do
        Form526Submission.create(
          user_uuid: user.uuid,
          saved_claim_id: saved_claim.id,
          auth_headers_json: auth_headers.to_json,
          form_json: hypertension_form_json
        )
      end

      context 'Flipper is enabled' do
        before do
          Flipper.enable :rrd_hypertension_compensation
          Flipper.enable :rrd_asthma_compensation
        end

        it 'calls start_rrd_job with the job and backup job classes' do
          expect(form_for_hypertension).to receive(:start_rrd_job)
            .with(RapidReadyForDecision::Form526BaseJob,
                  { use_backup_job: true })
          form_for_hypertension.start
        end

        context 'when RRD job class has failed all retries and Sidekiq::Batch calls rrd_processor_failed_handler' do
          # Sidekiq::Batch creates a new Form526Submission in order to call *_handler methods
          let(:sidekiq_submission) { Form526Submission.new }
          let(:backup_sidekiq_job) { RapidReadyForDecision::DisabilityCompensationJob }

          before do
            # return this exact instance to avoid flakey tests due to returning another instance of the same record
            allow(Form526Submission).to receive(:find).with(form_for_hypertension.id).and_return(form_for_hypertension)
          end

          it 'calls start_rrd_job with the backup job class if use_backup_job=true' do
            expect(form_for_hypertension).to receive(:start_rrd_job).with(backup_sidekiq_job)
            expect(form_for_hypertension).to receive(:send_rrd_alert_email)
              .with('RRD Processor Selector alert - backup job',
                    "Restarting with backup #{backup_sidekiq_job} for submission #{form_for_hypertension.id}.")
            sidekiq_submission.rrd_processor_failed_handler('ignored Sidekiq::Batch::Status',
                                                            'submission_id' => form_for_hypertension.id,
                                                            'use_backup_job' => true)
          end

          it 'calls start_evss_submission_job if use_backup_job=false' do
            expect(form_for_hypertension).to receive(:start_evss_submission_job)
            sidekiq_submission.rrd_processor_failed_handler('ignored Sidekiq::Batch::Status',
                                                            'submission_id' => form_for_hypertension.id,
                                                            'use_backup_job' => false)
          end

          context 'when an error is raised within rrd_processor_failed_handler' do
            before do
              allow_any_instance_of(RapidReadyForDecision::SidekiqJobSelector)
                .to receive(:sidekiq_job).and_raise('Any error')
            end

            it 'calls start_evss_submission_job and sends a alert' do
              expect(form_for_hypertension).to receive(:start_evss_submission_job)
              expect(form_for_hypertension).to receive(:send_rrd_alert_email)
                .with('RRD Processor Selector alert',
                      /RRD was skipped for submission #{form_for_hypertension.id} due to an error./, anything)
              sidekiq_submission.rrd_processor_failed_handler('ignored Sidekiq::Batch::Status',
                                                              'submission_id' => form_for_hypertension.id,
                                                              'use_backup_job' => true)
            end
          end
        end

        it 'queues a new RapidReadyForDecision::Form526BaseJob worker' do
          expect do
            form_for_hypertension.start
          end.to change(RapidReadyForDecision::Form526BaseJob.jobs, :size).by(1)
        end

        it_behaves_like '#start_evss_submission'

        context 'an exception is raised in the start method' do
          it 'calls start_evss_submission_job' do
            allow(Sidekiq::Batch).to receive(:new).and_raise(NoMethodError)

            expect(Rails.logger).to receive(:error)
            expect(form_for_hypertension).to receive(:start_evss_submission_job)
            form_for_hypertension.start
          end
        end
      end

      context 'Flipper is disabled' do
        before do
          Flipper.disable :rrd_hypertension_compensation
          Flipper.disable :rrd_asthma_compensation
        end

        it 'does NOT queue a new RapidReadyForDecision::Form526BaseJob worker' do
          expect { subject.start }.to change(RapidReadyForDecision::Form526BaseJob.jobs, :size).by(0)
        end

        it_behaves_like '#start_evss_submission'
      end
    end

    context 'the submission is NOT for hypertension' do
      it 'Does NOT queue a new RapidReadyForDecision::Form526BaseJob' do
        expect { subject.start }.to change(RapidReadyForDecision::Form526BaseJob.jobs, :size).by(0)
      end

      it_behaves_like '#start_evss_submission'
    end
  end

  describe '#start_evss_submission_job' do
    it_behaves_like '#start_evss_submission'
  end

  describe '#submit_with_birls_id_that_hasnt_been_tried_yet!' do
    context 'when it is all claims' do
      it 'queues an all claims job' do
        expect(subject.birls_id).to be_truthy
        expect(subject.birls_ids.count).to eq 1
        subject.birls_ids_tried = { subject.birls_id => ['some timestamp'] }.to_json
        subject.save!
        expect { subject.submit_with_birls_id_that_hasnt_been_tried_yet! }.to(
          change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(0)
        )
        next_birls_id = "#{subject.birls_id}cat"
        subject.add_birls_ids next_birls_id
        expect { subject.submit_with_birls_id_that_hasnt_been_tried_yet! }.to(
          change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(1)
        )
        expect(subject.birls_id).to eq next_birls_id
      end
    end
  end

  describe '#form' do
    it 'returns the form as a hash' do
      expect(subject.form).to eq(JSON.parse(form_json))
    end
  end

  describe '#form_to_json' do
    context 'with form 526' do
      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_526)).to eq(JSON.parse(form_json)['form526'].to_json)
      end
    end

    context 'with form 4142' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end

      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_4142)).to eq(JSON.parse(form_json)['form4142'].to_json)
      end
    end

    context 'with form 0781' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_0781.json')
      end

      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_0781)).to eq(JSON.parse(form_json)['form0781'].to_json)
      end
    end

    context 'with form 8940' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_8940.json')
      end

      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_8940)).to eq(JSON.parse(form_json)['form8940'].to_json)
      end
    end
  end

  describe '#auth_headers' do
    it 'returns the parsed auth headers' do
      expect(subject.auth_headers).to eq(auth_headers)
    end
  end

  describe '#add_birls_ids' do
    subject do
      headers = JSON.parse auth_headers.to_json
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    context 'birls_ids_tried nil' do
      let(:birls_ids_tried) { nil }

      it 'has no default' do
        expect(subject.birls_ids_tried).to eq 'null'
      end

      context 'using nil as an id' do
        it 'results in an empty hash' do
          subject.add_birls_ids nil
          expect(JSON.parse(subject.birls_ids_tried)).to be_a Hash
        end
      end

      context 'single id' do
        it 'initializes with an empty array' do
          subject.add_birls_ids 'a'
          expect(subject.birls_ids_tried_hash).to eq 'a' => []
        end
      end

      context 'an array of ids' do
        it 'initializes with an empty arrays' do
          subject.add_birls_ids(%w[a b c])
          expect(subject.birls_ids_tried_hash).to eq 'a' => [], 'b' => [], 'c' => []
        end
      end
    end

    context 'birls_ids_tried already has values' do
      let(:birls_ids_tried) { { 'a' => ['2021-02-01T14:28:33Z'] } }

      context 'using nil as an id' do
        it 'results in an empty hash' do
          subject.add_birls_ids nil
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried
        end
      end

      context 'single id that is already present' do
        it 'does nothing' do
          subject.add_birls_ids 'a'
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried
        end
      end

      context 'single id that is not already present' do
        it 'does nothing' do
          subject.add_birls_ids 'b'
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried.merge('b' => [])
        end
      end

      context 'an array of ids' do
        it 'initializes with an empty arrays, for ids that area not already present' do
          subject.add_birls_ids(['a', :b, :c])
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried.merge('b' => [], 'c' => [])
        end
      end

      context 'an array of ids persisted' do
        it 'persists' do
          subject.add_birls_ids(['a', :b, :c])
          subject.save
          subject.reload
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried.merge('b' => [], 'c' => [])
        end
      end
    end
  end

  describe '#birls_ids' do
    subject do
      headers = JSON.parse auth_headers.to_json
      headers['va_eauth_birlsfilenumber'] = birls_id
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    let(:birls_id) { 'a' }
    let(:birls_ids_tried) { { b: [], c: ['2021-02-01T14:28:33Z'] } }

    context 'birls_ids_tried present and auth_headers present' do
      it 'lists all birls ids' do
        expect(subject.birls_ids).to contain_exactly 'c', 'b', 'a'
      end

      it 'persists' do
        subject.save
        subject.reload
        expect(subject.birls_ids).to contain_exactly 'b', 'c', 'a'
      end
    end

    context 'only birls_ids_tried present' do
      subject do
        Form526Submission.new(
          user_uuid: user.uuid,
          saved_claim_id: saved_claim.id,
          form_json:,
          birls_ids_tried: birls_ids_tried.to_json
        )
      end

      it 'lists birls ids from birls_ids_tried only' do
        expect(subject.birls_ids).to contain_exactly 'b', 'c'
      end
    end

    context 'only auth_headers present' do
      let(:birls_ids_tried) { nil }

      it 'lists birls ids from auth_headers only' do
        expect(subject.birls_ids).to contain_exactly 'a'
      end
    end
  end

  describe '#mark_birls_id_as_tried' do
    subject do
      headers = JSON.parse auth_headers.to_json
      headers['va_eauth_birlsfilenumber'] = birls_id
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    let(:birls_id) { 'a' }

    context 'nil birls_ids_tried' do
      let(:birls_ids_tried) { nil }

      it 'adds the current birls id to birls_ids_tried' do
        expect(JSON.parse(subject.birls_ids_tried)).to eq birls_ids_tried
        subject.mark_birls_id_as_tried
        expect(subject.birls_ids_tried_hash.keys).to contain_exactly 'a'
        subject.save
        subject.reload
        expect(subject.birls_ids_tried_hash.keys).to contain_exactly 'a'
      end
    end

    context 'previous attempts' do
      let(:birls_ids_tried) { { 'b' => ['2021-02-01T14:28:33Z'] } }

      it 'adds the current BIRLS ID to birls_ids_tried array (turns birls_ids_tried into an array if nil)' do
        expect(JSON.parse(subject.birls_ids_tried)).to eq birls_ids_tried
        subject.mark_birls_id_as_tried
        expect(subject.birls_ids_tried_hash.keys).to match_array [birls_id, *birls_ids_tried.keys]
        subject.save
        subject.reload
        expect(subject.birls_ids_tried_hash.keys).to match_array [birls_id, *birls_ids_tried.keys]
      end
    end
  end

  describe '#birls_ids_that_havent_been_tried_yet' do
    subject do
      headers = JSON.parse auth_headers.to_json
      headers['va_eauth_birlsfilenumber'] = birls_id
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    let(:birls_id) { 'a' }
    let(:birls_ids_tried) { { b: [], c: ['2021-02-01T14:28:33Z'], d: nil } }

    it 'does not include birls ids that have already been tried' do
      expect(subject.birls_ids_that_havent_been_tried_yet).to contain_exactly('a', 'b', 'd')
    end
  end

  describe '#birls_id!' do
    it 'returns the BIRLS ID' do
      expect(subject.birls_id!).to eq(auth_headers[described_class::BIRLS_KEY])
    end

    context 'auth_headers is nil' do
      it 'throws an exception' do
        subject.auth_headers_json = nil
        expect { subject.birls_id! }.to raise_error TypeError
      end
    end

    context 'auth_headers is unparseable' do
      it 'throws an exception' do
        subject.auth_headers_json = 'hi!'
        expect { subject.birls_id! }.to raise_error JSON::ParserError
      end
    end
  end

  describe '#birls_id' do
    it 'returns the BIRLS ID' do
      expect(subject.birls_id).to eq(auth_headers[described_class::BIRLS_KEY])
    end

    context 'auth_headers is nil' do
      it 'returns nil' do
        subject.auth_headers_json = nil
        expect(subject.birls_id).to be_nil
      end
    end

    context 'auth_headers is unparseable' do
      it 'throws an exception' do
        subject.auth_headers_json = 'hi!'
        expect { subject.birls_id }.to raise_error JSON::ParserError
      end
    end
  end

  describe '#birls_id=' do
    let(:birls_id) { 1 }

    it 'sets the BIRLS ID' do
      subject.birls_id = birls_id
      expect(subject.birls_id).to eq(birls_id)
    end

    context 'auth_headers is nil' do
      it 'throws an exception' do
        subject.auth_headers_json = nil
        expect { subject.birls_id = birls_id }.to raise_error TypeError
      end
    end

    context 'auth_headers is unparseable' do
      it 'throws an exception' do
        subject.auth_headers_json = 'hi!'
        expect { subject.birls_id = birls_id }.to raise_error JSON::ParserError
      end
    end
  end

  describe '#perform_ancillary_jobs_handler' do
    let(:status) { OpenStruct.new(parent_bid: SecureRandom.hex(8)) }

    context 'with an ancillary job' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 3 jobs' do
        subject.form526_job_statuses <<
          Form526JobStatus.new(job_class: 'SubmitForm526AllClaim', status: 'success', job_id: 0)
        expect do
          subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(3)
      end

      it 'warns when there are multiple successful submit526 jobs' do
        2.times do |index|
          subject.form526_job_statuses << Form526JobStatus.new(
            job_class: 'SubmitForm526AllClaim',
            status: Form526JobStatus::STATUS[:success],
            job_id: index
          )
        end
        expect(Form526JobStatus.all.count).to eq 2
        expect_any_instance_of(Form526Submission).to receive(:log_message_to_sentry).with(
          'There are multiple successful SubmitForm526 job statuses',
          :warn,
          { form_526_submission_id: subject.id }
        )
        subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
      end

      it "warns when there's a successful submit526 job, but it's not the most recent submit526 job" do
        %i[success retryable_error].each_with_index do |status, index|
          subject.form526_job_statuses << Form526JobStatus.new(
            job_class: 'SubmitForm526AllClaim',
            status: Form526JobStatus::STATUS[status],
            job_id: index,
            updated_at: Time.zone.now + index.days
          )
        end
        expect(Form526JobStatus.all.count).to eq 2
        expect_any_instance_of(Form526Submission).to receive(:log_message_to_sentry).with(
          "There is a successful SubmitForm526 job, but it's not the most recent SubmitForm526 job",
          :warn,
          { form_526_submission_id: subject.id }
        )
        subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
      end
    end
  end

  describe '#perform_ancillary_jobs' do
    let(:first_name) { 'firstname' }

    context 'with (3) uploads' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 3 upload jobs' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(3)
      end
    end

    context 'with flashes' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      context 'when feature enabled' do
        before { Flipper.enable(:disability_compensation_flashes) }

        it 'queues flashes job' do
          expect do
            subject.perform_ancillary_jobs(first_name)
          end.to change(BGS::FlashUpdater.jobs, :size).by(1)
        end
      end

      context 'when feature disabled' do
        before { Flipper.disable(:disability_compensation_flashes) }

        it 'queues flashes job' do
          expect do
            subject.perform_ancillary_jobs(first_name)
          end.to change(BGS::FlashUpdater.jobs, :size).by(0)
        end
      end
    end

    context 'BDD' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/526_bdd.json')
      end

      it 'queues 1 UploadBddInstructions job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::UploadBddInstructions.jobs, :size).by(1)
      end
    end

    context 'with form 4142' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end

      it 'queues a 4142 job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(CentralMail::SubmitForm4142Job.jobs, :size).by(1)
      end
    end

    context 'with form 0781' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_0781.json')
      end

      it 'queues a 0781 job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm0781.jobs, :size).by(1)
      end
    end

    context 'with form 8940' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_8940.json')
      end

      it 'queues a 8940 job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm8940.jobs, :size).by(1)
      end
    end
  end

  describe '#get_first_name' do
    [
      {
        input: 'Joe',
        expected: 'JOE'
      },
      {
        input: 'JOE',
        expected: 'JOE'
      }, {
        input: 'joe mark',
        expected: 'JOE MARK'
      }
    ].each do |test_param|
      it 'gets correct first name' do
        allow(User).to receive(:find).with(anything).and_return(user)
        allow_any_instance_of(User).to receive(:first_name).and_return(test_param[:input])

        expect(subject.get_first_name).to eql(test_param[:expected])
      end
    end

    context 'when the first name is NOT populated on the User' do
      before do
        # Ensure `subject` is called before stubbing `first_name` so that the auth headers are populated correctly
        subject
        user_with_nil_first_name = User.create(user)
        allow(user_with_nil_first_name).to receive(:first_name).and_return nil
        allow(User).to receive(:find).with(subject.user_uuid).and_return user_with_nil_first_name
      end

      context 'when name attributes exist in the auth headers' do
        it 'returns the first name of the user from the auth headers' do
          expect(subject.get_first_name).to eql('BEYONCE')
        end
      end

      context 'when name attributes do NOT exist in the auth headers' do
        subject { build(:form526_submission, :with_empty_auth_headers) }

        it 'returns nil' do
          expect(subject.get_first_name).to be nil
        end
      end
    end

    context 'when the User is NOT found' do
      before { allow(User).to receive(:find).and_return nil }

      it 'returns the first name of the user from the auth headers' do
        expect(subject.get_first_name).to eql('BEYONCE')
      end
    end
  end

  describe '#full_name' do
    let(:full_name_hash) do
      {
        first: 'Beyonce',
        middle: nil,
        last: 'Knowles',
        suffix: user.normalized_suffix
      }
    end

    context 'when the full name exists on the User' do
      it 'returns the full name of the user' do
        expect(subject.full_name).to eql(full_name_hash)
      end
    end

    context 'when the full name is NOT populated on the User but name attributes exist in the auth_headers' do
      let(:nil_full_name_hash) do
        {
          first: nil,
          middle: nil,
          last: nil,
          suffix: nil
        }
      end

      before do
        allow_any_instance_of(User).to receive(:full_name_normalized).and_return nil_full_name_hash
      end

      context 'when name attributes exist in the auth headers' do
        it 'returns the first and last name of the user from the auth headers' do
          expect(subject.full_name).to eql(full_name_hash.merge(middle: nil, suffix: nil))
        end
      end

      context 'when name attributes do NOT exist in the auth headers' do
        subject { build(:form526_submission, :with_empty_auth_headers) }

        it 'returns the hash with all nil values' do
          expect(subject.full_name).to eql nil_full_name_hash
        end
      end
    end

    context 'when the User is NOT found' do
      before { allow(User).to receive(:find).and_return nil }

      it 'returns the first and last name of the user from the auth headers' do
        expect(subject.full_name).to eql(full_name_hash.merge(middle: nil, suffix: nil))
      end
    end
  end

  describe '#workflow_complete_handler' do
    describe 'success' do
      let(:options) do
        {
          'submission_id' => subject.id,
          'first_name' => 'firstname'
        }
      end

      context 'with a single successful job' do
        subject { create(:form526_submission, :with_one_succesful_job) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_truthy
        end
      end

      context 'with multiple successful jobs' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_truthy
        end
      end

      context 'with multiple successful jobs and email and submitted time in PM' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

        before { Timecop.freeze(Time.zone.parse('2012-07-20 14:15:00 UTC')) }

        after { Timecop.return }

        it 'calls confirmation email job with correct personalization' do
          allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
            expect(args[0]['first_name']).to eql('firstname')
            expect(args[0]['submitted_claim_id']).to be(123_654_879)
            expect(args[0]['email']).to eql('test@email.com')
            expect(args[0]['date_submitted']).to eql('July 20, 2012 2:15 p.m. UTC')
          end

          subject.workflow_complete_handler(nil, options)
        end
      end

      context 'with multiple successful jobs and email and submitted time in PM with two digit hour' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

        before { Timecop.freeze(Time.zone.parse('2012-07-20 11:12:00 UTC')) }

        after { Timecop.return }

        it 'calls confirmation email job with correct personalization' do
          allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
            expect(args[0]['first_name']).to eql('firstname')
            expect(args[0]['submitted_claim_id']).to be(123_654_879)
            expect(args[0]['email']).to eql('test@email.com')
            expect(args[0]['date_submitted']).to eql('July 20, 2012 11:12 a.m. UTC')
          end

          subject.workflow_complete_handler(nil, options)
        end
      end

      context 'with multiple successful jobs and email and submitted time in morning' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

        before { Timecop.freeze(Time.zone.parse('2012-07-20 8:07:00 UTC')) }

        after { Timecop.return }

        it 'calls confirmation email job with correct personalization' do
          allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
            expect(args[0]['first_name']).to eql('firstname')
            expect(args[0]['submitted_claim_id']).to be(123_654_879)
            expect(args[0]['email']).to eql('test@email.com')
            expect(args[0]['date_submitted']).to eql('July 20, 2012 8:07 a.m. UTC')
          end

          subject.workflow_complete_handler(nil, options)
        end
      end

      context 'with submission confirmation email when successful job statuses' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs) }

        it 'returns one job triggered' do
          expect do
            subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
        end
      end
    end

    describe 'failure' do
      context 'with mixed result jobs' do
        subject { create(:form526_submission, :with_mixed_status) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_falsey
        end
      end

      context 'with a failing 526 form job' do
        subject { create(:form526_submission, :with_one_failed_job) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_falsey
        end
      end

      context 'with submission confirmation email when failed job statuses' do
        subject { create(:form526_submission, :with_mixed_status) }

        it 'returns zero jobs triggered' do
          expect do
            subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          end.to change(Form526ConfirmationEmailJob.jobs, :size).by(0)
        end
      end

      it 'sends a submission failed email notification' do
        expect do
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
        end.to change(Form526SubmissionFailedEmailJob.jobs, :size).by(1)
      end
    end
  end

  describe '#disabilities_not_service_connected?' do
    subject { form_526_submission.disabilities_not_service_connected? }

    let(:form_526_submission) do
      Form526Submission.create(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: auth_headers.to_json,
        form_json: File.read("spec/support/disability_compensation_form/submissions/#{form_json_filename}")
      )
    end

    before { VCR.insert_cassette('evss/disability_compensation_form/rated_disabilities_with_non_service_connected') }
    after { VCR.eject_cassette('evss/disability_compensation_form/rated_disabilities_with_non_service_connected') }

    context 'when all corresponding rated disabilities are not service-connected' do
      let(:form_json_filename) { 'only_526_asthma.json' }

      it 'returns true' do
        expect(subject).to be_truthy
      end
    end

    context 'when some but not all corresponding rated disabilities are not service-connected' do
      let(:form_json_filename) { 'only_526_two_rated_disabilities.json' }

      it 'returns false' do
        expect(subject).to be_falsey
      end
    end

    context 'when some disabilities do not have a ratedDisabilityId yet' do
      let(:form_json_filename) { 'only_526_mixed_action_disabilities.json' }

      it 'returns false' do
        expect(subject).to be_falsey
      end
    end
  end
end
