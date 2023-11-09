class AddStateToForm5655Submission < ActiveRecord::Migration[6.1]
  def change
    add_column :form5655_submissions, :state, :integer, default: 0
    add_column :form5655_submissions, :error_message, :string
  end
end
