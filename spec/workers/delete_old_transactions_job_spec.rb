# frozen_string_literal: true

require 'sidekiq/testing'
Sidekiq::Testing.fake!

describe DeleteOldTransactionsJob do
  context 'if an exception happens' do
    before do
      allow_any_instance_of(AsyncTransaction::Vet360::AddressTransaction)
        .to receive(:destroy!)
        .and_raise(ActiveRecord::RecordNotDestroyed, 'BOOM!')
    end

    it 'rescues and logs the details' do
      create(:address_transaction,
             created_at: (Time.current - AsyncTransaction::Base::DELETE_COMPLETED_AFTER - 1.day).iso8601,
             status: AsyncTransaction::Base::COMPLETED)

      job = DeleteOldTransactionsJob.new
      job.should_receive(:log_message_to_sentry).once
      job.perform
    end
  end
end
