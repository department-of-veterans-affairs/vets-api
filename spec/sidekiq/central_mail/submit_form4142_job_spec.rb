# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_auth_headers' # required to build a Form526Submission

RSpec.describe CentralMail::SubmitForm4142Job, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:evss_claim_id) { 123_456_789 }
  let(:saved_claim) { FactoryBot.create(:va526ez) }

  describe '.perform_async' do
    let(:form_json) do
      File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
    end
    let(:submission) do
      Form526Submission.create(user_uuid: user.uuid,
                               auth_headers_json: auth_headers.to_json,
                               saved_claim_id: saved_claim.id,
                               form_json:,
                               submitted_claim_id: evss_claim_id)
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
end
