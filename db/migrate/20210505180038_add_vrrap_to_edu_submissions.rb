class AddVrrapToEduSubmissions < ActiveRecord::Migration[6.0]
  def change
    add_column(:education_benefits_submissions, :vrrap, :boolean, default: false, null: false)
  end
end
