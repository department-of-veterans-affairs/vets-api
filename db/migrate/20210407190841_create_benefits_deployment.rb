class CreateBenefitsDeployment < ActiveRecord::Migration[6.0]
  def change
    create_table :vba_documents_git_items do |t|
      t.string :url, null: false, unique: true
      t.jsonb :git_item
      t.boolean :notified, default: false
      t.string :label
      t.timestamps
    end
    add_index(:vba_documents_git_items, [:url, :notified, :label])
  end
end
