# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526IncreaseOnly, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  subject { described_class }

  describe '.perform_async' do
    let(:valid_form_content) do
      File.read 'spec/support/disability_compensation_form/front_end_submission_with_uploads.json'
    end
    let(:form4142) { File.read 'spec/support/disability_compensation_form/form_4142.json' }
    let(:transaction_class) { AsyncTransaction::EVSS::VA526ezSubmitTransaction }
    let(:last_transaction) { transaction_class.last }
    let(:claim) { FactoryBot.create(:va526ez) }
    let(:submission) do
      {
        'form526' => valid_form_content,
        'form526_uploads' => [{
          'guid' => 'foo',
          'file_name' => 'bar.pdf',
          'doctype' => 'L023'
        }],
        'form4142' => form4142
      }
    end
    let(:disability_compensation_submission) { instance_double('DisabilityCompensationSubmission') }

    context 'with a successfull submission job' do
      before do
        allow_any_instance_of(
          AsyncTransaction::EVSS::VA526ezSubmitTransaction
        ).to receive(:submission).and_return(disability_compensation_submission)
        allow(disability_compensation_submission).to receive(:id).and_return(123)
      end

      it 'queues a job for submit' do
        expect do
          subject.perform_async(user.uuid, auth_headers, submission)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          expect_any_instance_of(subject).to receive(:perform_ancillary_jobs)
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'received'
        end
      end

      it 'kicks off the ancillary jobs with the response claim id' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          claim_id = SecureRandom.uuid
          response = double(:response, claim_id: claim_id, attributes: nil)
          service = double(:service, submit_form526: response)
          transaction = double(:transaction)
          allow(EVSS::DisabilityCompensationForm::Service)
            .to receive(:new).and_return(service)
          allow(AsyncTransaction::EVSS::VA526ezSubmitTransaction)
            .to receive(:find_transaction).and_return(transaction)
          allow(AsyncTransaction::EVSS::VA526ezSubmitTransaction)
            .to receive(:update_transaction).and_return(transaction)
          allow(transaction).to receive(:submission).and_return(disability_compensation_submission)

          expect_any_instance_of(subject).to receive(:perform_ancillary_jobs).with(claim_id)
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          described_class.drain
        end
      end

      it 'assigns the saved claim via the xref table' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          described_class.drain
          expect(last_transaction.saved_claim.id).to eq claim.id
        end
      end
    end

    context 'when retrying a job' do
      before do
        allow_any_instance_of(
          AsyncTransaction::EVSS::VA526ezSubmitTransaction
        ).to receive(:submission).and_return(disability_compensation_submission)
        allow(disability_compensation_submission).to receive(:id).and_return(123)
      end

      it 'doesnt recreate the transaction' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          expect_any_instance_of(subject).to receive(:perform_ancillary_jobs)
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)

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
        transaction = double(:transaction)
        allow(AsyncTransaction::EVSS::VA526ezSubmitTransaction)
          .to receive(:find_transaction).and_return(transaction)
        allow(transaction).to receive(:submission).and_return(disability_compensation_submission)
        allow(disability_compensation_submission).to receive(:id).and_return(123)
      end

      it 'sets the transaction to "retrying"' do
        subject.perform_async(user.uuid, auth_headers, claim.id, submission)
        expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
          anything, :retrying, error: 'Gateway timeout'
        )
        expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_retryable).once
        expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::GatewayTimeout)
      end
    end

    context 'with a client error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.serviceInformation.ConfinementPastActiveDutyDate',
            'severity' => 'ERROR',
            'text' => 'The confinement start date is too far in the past'
          },
          {
            'key' => 'form526.serviceInformation.ConfinementWithInServicePeriod',
            'severity' => 'ERROR',
            'text' => 'Your period of confinement must be within a single period of service'
          },
          {
            'key' => 'form526.veteran.homelessness.pointOfContact.pointOfContactName.Pattern',
            'severity' => 'ERROR',
            'text' => 'must match "([a-zA-Z0-9-/]+( ?))*$"'
          }
        ]
      end

      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
            anything, :non_retryable_error, expected_errors
          )
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
        end
      end
    end

    context 'with a server error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.establishClaim.serviceError',
            'text' => 'form526.submit.establishClaim.serviceError',
            'severity' => 'FATAL'
          }
        ]
      end

      it 'sets the transaction to non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_err_msg') do
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
            anything, :non_retryable_error, expected_errors
          )
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
        end
      end
    end

    context 'with a max ep code server error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.save.draftForm.MaxEPCode',
            'severity' => 'FATAL',
            'text' => 'This claim could not be established. ' \
'The Maximum number of EP codes have been reached for this benefit type claim code'
          }
        ]
      end

      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_max_ep_code') do
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
            anything, :non_retryable_error, expected_errors
          )
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
        end
      end
    end

    context 'with a pif in use server error' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.save.draftForm.MaxEPCode',
            'severity' => 'FATAL',
            'text' => 'Claim could not be established. ' \
'Contact the BDN team and have them run the WIPP process to delete Cancelled/Cleared PIFs'
          }
        ]
      end

      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_pif_in_use') do
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
            anything, :non_retryable_error, expected_errors
          )
          expect_any_instance_of(EVSS::DisabilityCompensationForm::Metrics).to receive(:increment_non_retryable).once
          described_class.drain
        end
      end
    end

    context 'with an error that is not mapped' do
      let(:expected_errors) do
        [
          {
            'key' => 'form526.submit.save.draftForm.UnmappedError',
            'severity' => 'FATAL',
            'text' => 'This is an unmapped error message'
          }
        ]
      end

      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_unmapped') do
          subject.perform_async(user.uuid, auth_headers, claim.id, submission)
          expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
            anything, :non_retryable_error, expected_errors
          )
          described_class.drain
        end
      end
    end

    context 'with an unexpected error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(StandardError.new('foo'))
      end

      it 'sets the transaction to "non_retryable_error"' do
        expect_any_instance_of(described_class).to receive(:log_exception_to_sentry)
        subject.perform_async(user.uuid, auth_headers, claim.id, submission)
        expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction).to receive(:update_transaction).with(
          anything, :non_retryable_error, error: 'foo'
        )
        described_class.drain
      end
    end
  end
end
