# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form526Submission do
  subject do
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers_json: auth_headers.to_json,
      form_json: form_json
    )
  end

  let(:user) { build(:disabilities_compensation_user) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:form_json) do
    File.read('spec/support/disability_compensation_form/submissions/only_526.json')
  end

  describe '#start' do
    before { Sidekiq::Worker.clear_all }

    context 'when it is all claims' do
      it 'queues an all claims job' do
        expect { subject.start }.to change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(1)
      end
    end
  end

  describe '#start_but_use_a_birls_id_that_hasnt_been_tried_yet!' do
    before do
      Sidekiq::Worker.clear_all
      Settings.mvi.edipi_search = true
    end

    context 'when it is all claims' do
      it 'queues an all claims job' do
        expect(subject.birls_id).to be_truthy
        expect(subject.birls_ids.count).to eq 1
        subject.birls_ids_tried = { subject.birls_id => ['some timestamp'] }.to_json
        subject.save!
        expect { subject.start_but_use_a_birls_id_that_hasnt_been_tried_yet! }.to(
          change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(0)
        )
        next_birls_id = subject.birls_id + 'cat'
        subject.add_birls_ids next_birls_id
        expect { subject.start_but_use_a_birls_id_that_hasnt_been_tried_yet! }.to(
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
        form_json: form_json,
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
        form_json: form_json,
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
          form_json: form_json,
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
        form_json: form_json,
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
        form_json: form_json,
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
  end

  describe '#workflow_complete_handler' do
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

    context 'with submission confirmation email when successful job statuses' do
      subject { create(:form526_submission, :with_multiple_succesful_jobs) }

      it 'returns one job triggered' do
        expect do
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
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
  end
end
