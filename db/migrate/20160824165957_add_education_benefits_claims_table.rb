class AddEducationBenefitsClaimsTable < ActiveRecord::Migration
  def change
    create_table(:education_benefits_claims) do |t|
      t.datetime(:submitted_at)
      t.datetime(:processed_at)
      t.json(:form, null: false)
      t.timestamps(null: false)
    end

    add_index(:education_benefits_claims, :submitted_at)
  end
end
