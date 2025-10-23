class CreateDebtTransactionLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :debt_transaction_logs, id: :uuid do |t|
      t.references :transactionable, polymorphic: true, null: false, type: :uuid
      t.string :transaction_type, null: false
      t.uuid :user_uuid, null: false
      t.jsonb :debt_identifiers, null: false, default: []
      t.jsonb :summary_data, default: {}
      t.string :state
      t.string :external_reference_id
      t.datetime :transaction_started_at, null: false
      t.datetime :transaction_completed_at
      t.timestamps
    end
  end
end
