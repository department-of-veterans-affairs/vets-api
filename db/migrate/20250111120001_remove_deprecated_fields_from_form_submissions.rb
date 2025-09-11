class RemoveDeprecatedFieldsFromFormSubmissions < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      remove_column :form_submissions, :legacy_data, :jsonb
      remove_column :form_submissions, :old_status, :string
      remove_column :form_submissions, :deprecated_at, :datetime
    end
  end
end