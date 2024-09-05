class AddDefaultStateToForm526Submissions < ActiveRecord::Migration[7.0]
   def up
     change_column_default :form526_submissions, :aasm_state, 'unprocessed'
   end
end
