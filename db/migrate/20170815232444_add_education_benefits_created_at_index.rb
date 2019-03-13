class AddEducationBenefitsCreatedAtIndex < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index(:education_benefits_claims, :created_at, algorithm: :concurrently)
  end
end
