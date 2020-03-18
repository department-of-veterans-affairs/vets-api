class RemoveDisabilityCompensationSubmissions < ActiveRecord::Migration[5.2]
  def change
    drop_table :disability_compensation_submissions
  end
end
