class AddCompleteToDisabilityCompensationSubmissions < ActiveRecord::Migration[4.2]
  def change
    add_column :disability_compensation_submissions, :complete, :boolean
  end
end

