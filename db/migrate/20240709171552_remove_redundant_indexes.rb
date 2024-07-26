class RemoveRedundantIndexes < ActiveRecord::Migration[7.1]
  def change
    remove_index :accreditations, name: 'index_accreditations_on_accredited_individual_id', if_exists: true

    remove_index :async_transactions, name: 'index_async_transactions_on_transaction_id', if_exists: true

    remove_index :va_notify_in_progress_reminders_sent, name: 'index_va_notify_in_progress_reminders_sent_on_user_account_id', if_exists: true
  end
end
