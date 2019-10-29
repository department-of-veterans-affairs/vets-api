# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::EVSS::VA526ezSubmitTransaction, type: :model do
  let(:user) { build(:user, :loa3) }
  let(:user_2) { build(:user, :loa3, uuid: SecureRandom.uuid) }
  let(:job_id) { SecureRandom.uuid }
  let(:job_id_2) { SecureRandom.uuid }
  let(:job_id_3) { SecureRandom.uuid }

  before do
    create(:va526ez_submit_transaction,
           user_uuid: user.uuid,
           source: 'EVSS',
           transaction_id: job_id)
    create(:va526ez_submit_transaction,
           user_uuid: user_2.uuid,
           source: 'EVSS',
           transaction_id: job_id_2)
    create(:va526ez_submit_transaction,
           user_uuid: user.uuid,
           source: 'EVSS',
           transaction_id: job_id_3)
    create(:email_transaction,
           transaction_id: '786efe0e-fd20-4da2-9019-0c00540dba4d',
           user_uuid: user.uuid,
           transaction_status: 'RECEIVED')
  end

  describe '.start' do
    it 'creates an asyn transaction' do
      expect do
        AsyncTransaction::EVSS::VA526ezSubmitTransaction.start(user.uuid, user.edipi, SecureRandom.uuid)
      end.to change { AsyncTransaction::EVSS::VA526ezSubmitTransaction.count }.by(1)
    end
  end

  describe '.find_transaction' do
    it 'finds a transaction by job_id', :aggregate_failures do
      transaction = AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(job_id)
      expect(transaction.user_uuid).to eq(user.uuid)
      expect(transaction.status).to eq('requested')
      expect(transaction.transaction_status).to eq('submitted')
      expect(transaction.transaction_id).to eq(job_id)
      expect(transaction.source).to eq('EVSS')
    end
  end

  describe '.find_transactions' do
    it 'finds all 526ez transactions for a user' do
      expect(AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transactions(user.uuid).count).to eq(2)
    end
    it 'finds only 526ez transactions for a user' do
      expect(
        AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transactions(user.uuid)
      ).to be_all do |t|
        t.class == AsyncTransaction::EVSS::VA526ezSubmitTransaction
      end
    end
  end

  describe '.update_transaction' do
    let(:update_job_id) { SecureRandom.uuid }
    let(:response_body) do
      {
        data: {
          messages: [],
          claim_id: 'abc123',
          inflightDocumentId: 0,
          end_product_claim_code: 'abc456',
          end_product_claim_name: 'abc789'
        }
      }
    end

    before do
      create(:va526ez_submit_transaction,
             user_uuid: user.uuid,
             source: 'EVSS',
             transaction_id: update_job_id)
    end

    context 'with a valid status of retrying' do
      it 'updates a transaction', :aggregate_failures do
        AsyncTransaction::EVSS::VA526ezSubmitTransaction.update_transaction(
          update_job_id,
          :retrying,
          response_body
        )
        expect(
          AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(update_job_id).transaction_status
        ).to eq('retrying')
        expect(
          AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(update_job_id).status
        ).to eq('requested')
      end
    end

    context 'with a valid status of received' do
      it 'updates a transaction', :aggregate_failures do
        AsyncTransaction::EVSS::VA526ezSubmitTransaction.update_transaction(
          update_job_id,
          :received,
          response_body
        )
        expect(
          AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(update_job_id).transaction_status
        ).to eq('received')
        expect(
          AsyncTransaction::EVSS::VA526ezSubmitTransaction.find_transaction(update_job_id).status
        ).to eq('completed')
      end
    end

    context 'with an invalid status' do
      it 'updates a transaction' do
        expect do
          AsyncTransaction::EVSS::VA526ezSubmitTransaction.update_transaction(
            update_job_id,
            :foo,
            response_body
          )
        end.to raise_error(ArgumentError, 'foo is not a valid status')
      end
    end
  end
end
