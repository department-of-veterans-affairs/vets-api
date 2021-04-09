class CreateFormsDeployment < ActiveRecord::Migration[6.0]
  def change
    create_table :va_forms_git_items do |t|
      t.string :url, null: false, unique: true
      t.jsonb :git_item
      t.boolean :notified, default: false
      t.timestamps
    end
    add_index(:va_forms_git_items, [:url, :notified], unique: true)
  end
end
