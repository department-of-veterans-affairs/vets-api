# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitForm526, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

  subject { described_class }

  describe '.perform_async' do
    let(:valid_form_content) { File.read 'spec/support/disability_compensation_form/fe_submission_with_uploads.json' }
    let(:last_transaction) { AsyncTransaction::EVSS::VA526ezSubmitTransaction.last }

    context 'with a successfull submission job' do
      it 'queues a job for submit' do
        expect do
          subject.perform_async(user.uuid, valid_form_content, nil)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'submits successfully' do
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, valid_form_content, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'received'
        end
      end

      it 'deletes the in progress form' do
        create(:in_progress_form, user_uuid: user.uuid, form_id: '21-526EZ')
        VCR.use_cassette('evss/disability_compensation_form/submit_form') do
          subject.perform_async(user.uuid, valid_form_content, nil)
          expect { described_class.drain }.to change { InProgressForm.count }.by(-1)
        end
      end
    end

    context 'with a submission timeout' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
      end

      it 'sets the transaction to "retrying"' do
        subject.perform_async(user.uuid, valid_form_content, nil)
        expect { described_class.drain }.to raise_error(Common::Exceptions::GatewayTimeout)
        expect(last_transaction.transaction_status).to eq 'retrying'
      end
    end

    context 'with a client error' do
      it 'sets the transaction to "non_retryable_error"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_400') do
          subject.perform_async(user.uuid, valid_form_content, nil)
          described_class.drain
          expect(last_transaction.transaction_status).to eq 'non_retryable_error'
        end
      end
    end

    context 'with a server error' do
      it 'sets the transaction to "retrying"' do
        VCR.use_cassette('evss/disability_compensation_form/submit_500_with_err_msg') do
          subject.perform_async(user.uuid, valid_form_content, nil)
          expect { described_class.drain }.to raise_error(EVSS::DisabilityCompensationForm::ServiceException)
          expect(last_transaction.transaction_status).to eq 'retrying'
        end
      end
    end
  end
end
