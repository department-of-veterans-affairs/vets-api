# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm0781, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:evss_claim_id) { 123_456_789 }
  let(:submission_id) { 123_456_790 }
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:form0781) { File.read 'spec/support/disability_compensation_form/form_0781.json' }

  subject { described_class }

  VCR.configure do |c|
    c.default_cassette_options = {
      match_requests_on: [:method,
                          VCR.request_matchers.uri_without_params(:qqfile, :docType, :docTypeDescription)]
    }
  end

  describe '.perform_async' do
    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(auth_headers, evss_claim_id, saved_claim.id, submission_id, form0781)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_0781') do
          subject.perform_async(auth_headers, evss_claim_id, saved_claim.id, submission_id, form0781)
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
        subject.perform_async(auth_headers, evss_claim_id, saved_claim.id, submission_id, form0781)
        expect { described_class.drain }.to raise_error(StandardError)
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'raises a standard error' do
        subject.perform_async(auth_headers, evss_claim_id, saved_claim.id, submission_id, form0781)
        expect { described_class.drain }.to raise_error(StandardError)
      end
    end
  end
end
