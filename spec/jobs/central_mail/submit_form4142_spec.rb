# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe CentralMail::SubmitForm4142Job, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  subject { described_class }

  describe '.perform_async' do
    let(:valid_form_content) { File.read 'spec/support/disability_compensation_form/form_4142.json' }
    let(:missing_postalcode_form_content) do
      File.read 'spec/support/disability_compensation_form/form_4142_missing_postalcode.json'
    end
    let(:evss_claim_id) { 123_456_789 }
    let(:submission_id) { 123_456_790 }
    let(:saved_claim) { FactoryBot.create(:va526ez) }

    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(evss_claim_id, saved_claim.id, submission_id, valid_form_content)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('central_mail/submit_4142') do
          subject.perform_async(evss_claim_id, saved_claim.id, submission_id, valid_form_content)
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
        subject.perform_async(evss_claim_id, saved_claim.id, submission_id, valid_form_content)
        expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a client error' do
      it 'raises a central mail response error' do
        VCR.use_cassette('central_mail/submit_4142_400') do
          subject.perform_async(
            evss_claim_id, saved_claim.id, submission_id, missing_postalcode_form_content
          )
          expect { described_class.drain }.to raise_error(CentralMail::SubmitForm4142Job::CentralMailResponseError)
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'raises a standard error' do
        subject.perform_async(evss_claim_id, saved_claim.id, submission_id, valid_form_content)
        expect { described_class.drain }.to raise_error(StandardError)
      end
    end
  end
end
