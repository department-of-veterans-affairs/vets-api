class CreateClaimVANotifications < ActiveRecord::Migration[7.1]
  def change
    create_table :claim_va_notifications do |t|
      t.string :form_type
      t.references :saved_claim, null: false, foreign_key: true
      t.boolean :email_sent
      t.integer :email_template_id

      t.timestamps
    end
  end
end
