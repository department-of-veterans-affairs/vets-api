class AddCompleteToDisabilityCompensationSubmissions < ActiveRecord::Migration
  def change
    add_column :disability_compensation_submissions, :complete, :boolean
  end
end

