class CreateTooltips < ActiveRecord::Migration[7.2]
  def change
    create_table :tooltips, id: :uuid do |t|
      t.references :user_account, null: false, foreign_key: { to_table: :user_accounts }, type: :uuid
      t.string :tooltip_name, null: false
      t.datetime :last_signed_in, null: false
      t.integer :counter, default: 0
      t.boolean :hidden, default: false
      t.timestamps
    end
    add_index :tooltips, [:user_account_id, :tooltip_name], unique: true
  end
end
