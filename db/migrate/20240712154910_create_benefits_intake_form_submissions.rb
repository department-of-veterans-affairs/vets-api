class CreateBenefitsIntakeFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    create_table :benefits_intake_form_submissions do |t|
      t.string :form_type, null: false
      t.uuid :benefits_intake_uuid
      t.uuid :submitted_claim_uuid
      t.jsonb :form_data, default: {}
      t.references :user_account, foreign_key: true, type: :uuid
      t.references :saved_claim, foreign_key: true
      t.references :in_progress_form, foreign_key: true
      t.text :encrypted_kms_key

      t.timestamps
    end

    add_index :benefits_intake_form_submissions, :benefits_intake_uuid
    add_index :benefits_intake_form_submissions, :submitted_claim_uuid
  end
end
