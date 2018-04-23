class CreateAsyncTransactions < ActiveRecord::Migration
  def change
    create_table :async_transactions do |t|

      t.timestamps null: false
    end
  end
end
