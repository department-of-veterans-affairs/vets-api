class CreateBenefitsDeployment < ActiveRecord::Migration[6.0]
  def change
    create_table :vba_documents_git_items do |t|
      t.string :url, null: false
      t.jsonb :git_item
      t.boolean :notified, default: false
      t.timestamps
    end
  end
end
