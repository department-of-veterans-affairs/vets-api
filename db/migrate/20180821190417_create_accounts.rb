class CreateAccounts < ActiveRecord::Migration[4.2]
  def change
    create_table :accounts do |t|
      t.uuid :uuid, null: false, unique: true
      t.string :idme_uuid
      t.string :icn
      t.string :edipi

      t.timestamps null: false
    end
  end
end
