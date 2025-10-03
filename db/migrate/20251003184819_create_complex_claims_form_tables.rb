class CreateComplexClaimsFormTables < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    create_table :travel_pay_complex_claims_form_sessions do |t|
      t.string :user_icn, null: false
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    add_index :travel_pay_complex_claims_form_sessions, :user_icn, algorithm: :concurrently
    add_index :travel_pay_complex_claims_form_sessions, :created_at, algorithm: :concurrently
    
    create_table :travel_pay_complex_claims_form_choices do |t|
      t.references :travel_pay_complex_claims_form_session, null: false, foreign_key: true
      t.string :expense_type, null: false
      t.jsonb :form_progress, default: []

      t.timestamps
    end
    
    add_index :travel_pay_complex_claims_form_choices, 
              [:travel_pay_complex_claims_form_session_id, :expense_type], 
              name: 'idx_complex_claims_choices_session_expense', 
              unique: true, 
              algorithm: :concurrently
  end
end
