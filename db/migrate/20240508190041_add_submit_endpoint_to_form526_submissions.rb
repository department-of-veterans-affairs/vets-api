class AddSubmitEndpointToForm526Submissions < ActiveRecord::Migration[7.1]
  def change
    add_column :form526_submissions, :submit_endpoint, :integer
  end
end
