class DropVersions < ActiveRecord::Migration[7.1]
  # This table was previously used to store version history for the `VAForms::Form` model
  # The `paper_trail` gem has since been removed, and all data has been migrated to the `va_forms_forms` table
  def change
    drop_table :versions
  end
end
