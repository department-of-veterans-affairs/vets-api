# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe Form526Submission do
  let(:user) { build(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:form_json) do
    File.read('spec/support/disability_compensation_form/submissions/only_526.json')
  end

  subject do
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers_json: auth_headers.to_json,
      form_json: form_json
    )
  end

  describe '#start' do
    before { Sidekiq::Worker.clear_all }

    context 'when it is increase only' do
      let(:klass) { EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly }

      it 'returns a bid' do
        expect(subject.start(klass)).to be_a(String)
      end

      it 'queues a increase only job' do
        expect { subject.start(klass) }.to change(klass.jobs, :size).by(1)
      end
    end

    context 'when it is all claims' do
      let(:klass) { EVSS::DisabilityCompensationForm::SubmitForm526AllClaim }

      it 'queues an all claims job' do
        expect { subject.start(klass) }.to change(klass.jobs, :size).by(1)
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
    let(:bid) { SecureRandom.hex(8) }

    context 'with (3) uploads' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 1 upload jobs' do
        expect do
          subject.perform_ancillary_jobs(bid)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(1)
      end
    end

    context 'with form 4142' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end

      it 'queues a 4142 job' do
        expect do
          subject.perform_ancillary_jobs(bid)
        end.to change(CentralMail::SubmitForm4142Job.jobs, :size).by(1)
      end
    end

    context 'with form 0781' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_0781.json')
      end

      it 'queues a 0781 job' do
        expect do
          subject.perform_ancillary_jobs(bid)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm0781.jobs, :size).by(1)
      end
    end

    context 'with form 8940' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_8940.json')
      end

      it 'queues a 8940 job' do
        expect do
          subject.perform_ancillary_jobs(bid)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm8940.jobs, :size).by(1)
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
  end
end
