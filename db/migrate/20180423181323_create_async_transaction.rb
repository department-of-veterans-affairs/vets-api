class CreateAsyncTransaction < ActiveRecord::Migration
  def change
    create_table :async_transactions do |t|
      t.string :type
      t.string :user_uuid
      t.string :source_id
      t.string :source
      t.string :status
      t.string :transaction_id
      t.string :transaction_status
    end
  end
end
