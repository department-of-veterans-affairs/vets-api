class AddEducationBenefitsSubmissionsTable < ActiveRecord::Migration
  def change
    create_table :education_benefits_submissions do |t|
      t.string(:region, null: false)
      t.datetime(:submitted_at, null: false)
      t.timestamps(null: false)

      EducationBenefitsClaim::APPLICATION_TYPES.each do |application_type|
        t.boolean(application_type, null: false)
      end
    end
  end
end
