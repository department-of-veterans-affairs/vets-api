class CreateDirectDeposits < ActiveRecord::Migration
  def change
    create_table :direct_deposits do |t|

      t.timestamps null: false
    end
  end
end
