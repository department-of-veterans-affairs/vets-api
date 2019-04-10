class AddEncryptedFormField < ActiveRecord::Migration[4.2]
  def change
    remove_column(:education_benefits_claims, :form)
    add_column(:education_benefits_claims, :encrypted_form, :string, null: false)
    add_column(:education_benefits_claims, :encrypted_form_iv, :string, null: false)
  end
end
