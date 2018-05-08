class AddEducationBenefitsSubmissionsTable < ActiveRecord::Migration
  safety_assured
  
  def change
    create_table :education_benefits_submissions do |t|
      t.string(:region, null: false)
      t.timestamps(null: false)

      %w(chapter33 chapter30 chapter1606 chapter32).each do |application_type|
        t.boolean(application_type, null: false, default: false)
      end
    end

    add_index(:education_benefits_submissions, [:region, :created_at])
  end
end
