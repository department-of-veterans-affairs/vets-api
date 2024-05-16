class AddStateToForm526Submissions < ActiveRecord::Migration[7.0]
  def change
    add_column :form526_submissions, :aasm_state, :string
  end
end
