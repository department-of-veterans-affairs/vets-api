# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe CentralMail::SubmitForm4142Job, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

  subject { described_class }

  describe '.perform_async' do
    let(:valid_form_content) { File.read 'spec/support/ancillary_forms/submit_form4142.json' }
    let(:transaction_class) { AsyncTransaction::CentralMail::VA4142SubmitTransaction }
    let(:last_transaction) { transaction_class.last }
    let(:claim) { FactoryBot.build(:va526ez) }

    before do
      Settings.sentry.dsn = 'asdf'
      claim.save!
    end

    after do
      Settings.sentry.dsn = nil
    end

    context 'with a successful submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(user.uuid,
                                valid_form_content, claim.id, Time.now.in_time_zone('Central Time (US & Canada)'))
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('central_mail/submit_4142') do
          subject.perform_async(user.uuid,
                                valid_form_content, claim.id, Time.now.in_time_zone('Central Time (US & Canada)'))
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'received'
        end
      end
    end

    context 'when retrying a job' do
      it 'doesnt recreate the transaction' do
        VCR.use_cassette('central_mail/submit_4142') do
          subject.perform_async(user.uuid,
                                valid_form_content, claim.id, Time.now.in_time_zone('Central Time (US & Canada)'))

          jid = subject.jobs.last['jid']
          transaction_class.start(user, jid)
          transaction_class.update_transaction(jid, :retrying, 'Test retry')

          described_class.drain
          expect(last_transaction.transaction_status).to eq 'received'
          expect(transaction_class.count).to eq 1
        end
      end
    end

    context 'with a submission timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'sets the transaction to "retrying"' do
        subject.perform_async(user.uuid,
                              valid_form_content, claim.id, nil)
        expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
        expect(last_transaction.transaction_status).to eq 'retrying'
      end
    end

    context 'with a client error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('central_mail/submit_4142_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(user.uuid,
                                valid_form_content, claim.id, Time.now.in_time_zone('Central Time (US & Canada)'))
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'non_retryable_error'
        end
      end
    end

    context 'with a server error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('central_mail/submit_4142_500') do
          subject.perform_async(user.uuid,
                                valid_form_content, claim.id, Time.now.in_time_zone('Central Time (US & Canada)'))
          expect { described_class.drain }.to raise_error(CentralMail::SubmitForm4142Job::CentralMailResponseError)
          expect(last_transaction.transaction_status).to eq 'retrying'
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
        subject.perform_async(user.uuid,
                              valid_form_content, claim.id, Time.now.in_time_zone('Central Time (US & Canada)'))
        described_class.drain
        expect(last_transaction.transaction_status).to eq 'non_retryable_error'
      end
    end
  end
end
