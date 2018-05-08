class AddFormTypeToEducationBenefitsSubmissions < ActiveRecord::Migration
  safety_assured
  
  def change
    add_column(:education_benefits_submissions, :form_type, :string, null: false, default: '1990')

    remove_index(:education_benefits_submissions, name: :index_education_benefits_submissions_on_region_and_created_at)
    add_index(:education_benefits_submissions, %w(region created_at form_type), name: 'index_edu_benefits_subs_ytd')
  end
end
