# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  subject { described_class }

  describe '.perform_async' do
    let(:valid_form_content) { File.read 'spec/support/disability_compensation_form/fe_submission_with_uploads.json' }
    let(:form4142) { File.read 'spec/support/disability_compensation_form/form_4142.json' }
    let(:transaction_class) { AsyncTransaction::EVSS::VA526ezSubmitTransaction }
    let(:last_transaction) { transaction_class.last }
    let(:claim) { FactoryBot.build(:va526ez) }

    before do
      claim.save!
    end

    context 'with a successfull submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(user.uuid, auth_headers, valid_form_content, nil, nil)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'received'
        end
      end

      it 'kicks off 4142 job' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          response = double(:response, claim_id: SecureRandom.uuid, attributes: nil)
          service = double(:service, submit_form526: response)
          transaction = double(:transaction)
          allow(EVSS::DisabilityCompensationForm::Service)
            .to receive(:new).and_return(service)
          allow(AsyncTransaction::EVSS::VA526ezSubmitTransaction)
            .to receive(:find_transaction).and_return(transaction)
          allow(AsyncTransaction::EVSS::VA526ezSubmitTransaction)
            .to receive(:update_transaction).and_return(transaction)

          expect(CentralMail::SubmitForm4142Job).to receive(:perform_async)
          subject.new.perform(user.uuid, auth_headers, claim.id, valid_form_content, form4142, nil)
        end
      end

      it 'assigns the saved claim via the xref table' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          described_class.drain
          expect(last_transaction.saved_claim.id).to eq claim.id
        end
      end
    end

    context 'when retrying a job' do
      it 'doesnt recreate the transaction' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)

          jid = subject.jobs.last['jid']
          transaction_class.start(user.uuid, auth_headers['va_eauth_dodedipnid'], jid)
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
        subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
        expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::GatewayTimeout)
        expect(last_transaction.transaction_status).to eq 'retrying'
      end
    end

    context 'with a client error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'non_retryable_error'
        end
      end
    end

    context 'with a server error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_err_msg') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
          expect(last_transaction.transaction_status).to eq 'retrying'
        end
      end
    end

    context 'with a max ep code server error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_max_ep_code') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'non_retryable_error'
        end
      end
    end

    context 'with a pif in use server error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_pif_in_use') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'non_retryable_error'
        end
      end
    end

    context 'with an error that is not mapped' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_unmapped') do
          subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'non_retryable_error'
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
        subject.perform_async(user.uuid, auth_headers, claim.id, valid_form_content, nil, nil)
        described_class.drain
        expect(last_transaction.transaction_status).to eq 'non_retryable_error'
      end
    end
  end
end
