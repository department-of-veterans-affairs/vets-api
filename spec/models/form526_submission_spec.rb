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

  describe '#perform_ancillary_jobs_handler' do
    let(:status) { OpenStruct.new(parent_bid: SecureRandom.hex(8)) }

    context 'with an ancillary job' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 1 job' do
        expect do
          subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(1)
      end
    end
  end

  describe '#perform_ancillary_jobs' do
    context 'with (3) uploads' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 1 upload jobs' do
        expect do
          subject.perform_ancillary_jobs('some name')
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(1)
      end
    end

    context 'with form 4142' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end

      it 'queues a 4142 job' do
        expect do
          subject.perform_ancillary_jobs('some name')
        end.to change(CentralMail::SubmitForm4142Job.jobs, :size).by(1)
      end
    end

    context 'with form 0781' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_0781.json')
      end

      it 'queues a 0781 job' do
        expect do
          subject.perform_ancillary_jobs('some name')
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm0781.jobs, :size).by(1)
      end
    end

    context 'with form 8940' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_8940.json')
      end

      it 'queues a 8940 job' do
        expect do
          subject.perform_ancillary_jobs('some name')
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm8940.jobs, :size).by(1)
      end
    end
  end

  describe '#get_full_name' do
    [
      {
        input:
          {
            first_name: 'Joe',
            middle_name: 'Doe',
            last_name: 'Smith',
            suffix: 'Jr.'
          },
        expected: 'JOE DOE SMITH JR.'
      },
      {
        input:
          {
            first_name: 'Joe',
            middle_name: nil,
            last_name: 'Smith',
            suffix: nil
          },
        expected: 'JOE SMITH'
      }, {
        input:
          {
            first_name: 'Joe',
            middle_name: 'Doe',
            last_name: 'Smith',
            suffix: nil
          },
        expected: 'JOE DOE SMITH'
      }
    ].each do |test_param|
      it 'gets correct full name' do
        allow(User).to receive(:find).with(anything).and_return(user)
        allow_any_instance_of(User).to receive(:full_name_normalized).and_return(test_param[:input])

        expect(subject.get_full_name).to eql(test_param[:expected])
      end
    end
  end

  describe '#workflow_complete_handler' do
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
        Flipper.enable(:form526_confirmation_email)

        allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
          expect(args[0]['full_name']).to eql('some name')
          expect(args[0]['submitted_claim_id']).to be(123_654_879)
          expect(args[0]['email']).to eql('test@email.com')
          expect(args[0]['date_submitted']).to eql('July 20, 2012 2:15 p.m. UTC')
        end

        options = {
          'submission_id' => subject.id,
          'full_name' => 'some name'
        }
        subject.workflow_complete_handler(nil, options)
      end
    end

    context 'with multiple successful jobs and email and submitted time in PM with two digit hour' do
      subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

      before { Timecop.freeze(Time.zone.parse('2012-07-20 11:12:00 UTC')) }

      after { Timecop.return }

      it 'calls confirmation email job with correct personalization' do
        Flipper.enable(:form526_confirmation_email)

        allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
          expect(args[0]['full_name']).to eql('some name')
          expect(args[0]['submitted_claim_id']).to be(123_654_879)
          expect(args[0]['email']).to eql('test@email.com')
          expect(args[0]['date_submitted']).to eql('July 20, 2012 11:12 a.m. UTC')
        end

        options = {
          'submission_id' => subject.id,
          'full_name' => 'some name'
        }
        subject.workflow_complete_handler(nil, options)
      end
    end

    context 'with multiple successful jobs and email and submitted time in morning' do
      subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

      before { Timecop.freeze(Time.zone.parse('2012-07-20 8:07:00 UTC')) }

      after { Timecop.return }

      it 'calls confirmation email job with correct personalization' do
        Flipper.enable(:form526_confirmation_email)

        allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
          expect(args[0]['full_name']).to eql('some name')
          expect(args[0]['submitted_claim_id']).to be(123_654_879)
          expect(args[0]['email']).to eql('test@email.com')
          expect(args[0]['date_submitted']).to eql('July 20, 2012 8:07 a.m. UTC')
        end

        options = {
          'submission_id' => subject.id,
          'full_name' => 'some name'
        }
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

      it 'returns zero jobs triggered when feature flag disabled' do
        Flipper.disable(:form526_confirmation_email)
        expect do
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(0)
      end

      it 'returns one job triggered when feature flag enabled' do
        Flipper.enable(:form526_confirmation_email)
        expect do
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
      end
    end

    context 'with submission confirmation email when failed job statuses' do
      Flipper.enable(:form526_confirmation_email)
      subject { create(:form526_submission, :with_mixed_status) }

      it 'returns zero jobs triggered' do
        expect do
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
        end.to change(Form526ConfirmationEmailJob.jobs, :size).by(0)
      end
    end
  end
end
