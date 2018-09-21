# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AsyncTransaction::CentralMail::VA4142SubmitTransaction, type: :model do
  let(:user) { build(:user, :loa3) }
  let(:user_2) { build(:user, :loa3, uuid: SecureRandom.uuid) }
  let(:job_id) { SecureRandom.uuid }
  let(:job_id_2) { SecureRandom.uuid }
  let(:job_id_3) { SecureRandom.uuid }

  before do
    create(:va4142_submit_transaction,
           user_uuid: user.uuid,
           source: 'central_mail',
           transaction_id: job_id)
    create(:va4142_submit_transaction,
           user_uuid: user_2.uuid,
           source: 'central_mail',
           transaction_id: job_id_2)
    create(:va4142_submit_transaction,
           user_uuid: user.uuid,
           source: 'central_mail',
           transaction_id: job_id_3)
    create(:email_transaction,
           transaction_id: '786efe0e-fd20-4da2-9019-0c00540dba4e',
           user_uuid: user.uuid,
           transaction_status: 'RECEIVED')
  end

  describe '.start' do
    it 'creates an async transaction' do
      expect do
        AsyncTransaction::CentralMail::VA4142SubmitTransaction.start(user.uuid, user.edipi, SecureRandom.uuid)
      end.to change { AsyncTransaction::CentralMail::VA4142SubmitTransaction.count }.by(1)
    end
  end

  describe '.find_transaction' do
    it 'finds a transaction by job_id', :aggregate_failures do
      transaction = AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transaction(job_id)
      Rails.logger.info('transaction class' => transaction)
      expect(transaction.first.user_uuid).to eq(user.uuid)
      expect(transaction.first.status).to eq('requested')
      expect(transaction.first.transaction_status).to eq('submitted')
      expect(transaction.first.transaction_id).to eq(job_id)
      expect(transaction.first.source).to eq('central_mail')
    end
  end

  describe '.find_transactions' do
    it 'finds all 4142 transactions for a user' do
      expect(AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transactions(user.uuid).count).to eq(2)
    end
    it 'finds only 4142 transactions for a user' do
      expect(
        AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transactions(user.uuid).all? do |t|
          t.class == AsyncTransaction::CentralMail::VA4142SubmitTransaction
        end
      ).to be_truthy
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
      create(:va4142_submit_transaction,
             user_uuid: user.uuid,
             source: 'central_mail',
             transaction_id: update_job_id)
    end

    context 'with a valid status of retrying' do
      it 'updates a transaction', :aggregate_failures do
        AsyncTransaction::CentralMail::VA4142SubmitTransaction.update_transaction(
          update_job_id,
          :retrying,
          response_body
        )
        expect(
          AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transaction(
            update_job_id
          ).first.transaction_status
        ).to eq('retrying')
        expect(
          AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transaction(update_job_id).first.status
        ).to eq('requested')
      end
    end

    context 'with a valid status of received' do
      it 'updates a transaction', :aggregate_failures do
        AsyncTransaction::CentralMail::VA4142SubmitTransaction.update_transaction(
          update_job_id,
          :received,
          response_body
        )
        expect(
          AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transaction(
            update_job_id
          ).first.transaction_status
        ).to eq('received')
        expect(
          AsyncTransaction::CentralMail::VA4142SubmitTransaction.find_transaction(update_job_id).first.status
        ).to eq('completed')
      end
    end

    context 'with an invalid status' do
      it 'updates a transaction' do
        expect do
          AsyncTransaction::CentralMail::VA4142SubmitTransaction.update_transaction(
            update_job_id,
            :foo,
            response_body
          )
        end.to raise_error(ArgumentError, 'foo is not a valid status')
      end
    end
  end
end
