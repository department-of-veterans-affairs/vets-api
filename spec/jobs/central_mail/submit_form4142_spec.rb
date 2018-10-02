# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe CentralMail::SubmitForm4142Job, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  subject { described_class }

  describe '.perform_async' do
    let(:valid_form_content) { File.read 'spec/support/disability_compensation_form/form_4142.json' }
    let(:claim) { FactoryBot.build(:va526ez) }

    before do
      claim.save!
    end

    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(user.uuid, auth_headers,
                                valid_form_content, claim.id,
                                Time.now.in_time_zone('Central Time (US & Canada)'))
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('central_mail/submit_4142') do
          subject.perform_async(user.uuid, auth_headers,
                                valid_form_content, claim.id,
                                Time.now.in_time_zone('Central Time (US & Canada)'))
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
        subject.perform_async(user.uuid, auth_headers,
                              valid_form_content, claim.id, nil)
        expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'with a client error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('central_mail/submit_4142_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(user.uuid, auth_headers,
                                valid_form_content, claim.id,
                                Time.now.in_time_zone('Central Time (US & Canada)'))
          described_class.drain
        end
      end
    end

    context 'raises a central mail response error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('central_mail/submit_4142_500') do
          subject.perform_async(user.uuid, auth_headers,
                                valid_form_content, claim.id,
                                Time.now.in_time_zone('Central Time (US & Canada)'))
          expect { described_class.drain }.to raise_error(CentralMail::SubmitForm4142Job::CentralMailResponseError)
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
        subject.perform_async(user.uuid, auth_headers,
                              valid_form_content, claim.id,
                              Time.now.in_time_zone('Central Time (US & Canada)'))
        described_class.drain
      end
    end
  end
end
