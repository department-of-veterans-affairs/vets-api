class AddStatusToEducationBenefitsSubmissions < ActiveRecord::Migration
  safety_assured
  
  def change
    add_column(:education_benefits_submissions, :status, :string, null: false, default: 'submitted')
    EducationBenefitsSubmission.update_all(status: 'processed')

    add_column(:education_benefits_submissions, :education_benefits_claim_id, :integer)
    add_index(:education_benefits_submissions, :education_benefits_claim_id, unique: true, name: :index_education_benefits_claim_id)
  end
end
