# frozen_string_literal: true

class AddIndexesToFormIntakeSubmissions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Indexes for common query patterns
    # Using algorithm: :concurrently to avoid table locks in production
    
    add_index :form_intake_submissions, :aasm_state,
              algorithm: :concurrently
              
    add_index :form_intake_submissions, :benefits_intake_uuid,
              algorithm: :concurrently
              
    add_index :form_intake_submissions, %i[form_submission_id aasm_state],
              name: 'idx_form_intake_sub_on_form_sub_id_and_state',
              algorithm: :concurrently
              
    add_index :form_intake_submissions, %i[aasm_state created_at],
              name: 'idx_form_intake_sub_on_state_and_created',
              algorithm: :concurrently
              
    add_index :form_intake_submissions, :form_intake_submission_id,
              unique: true,
              name: 'idx_form_intake_sub_on_intake_id',
              where: "form_intake_submission_id IS NOT NULL",
              algorithm: :concurrently
              
    add_index :form_intake_submissions, :last_attempted_at,
              name: 'idx_form_intake_sub_on_last_attempted',
              where: "aasm_state = 'pending'",
              algorithm: :concurrently
  end
end
