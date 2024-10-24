class CreateBanners < ActiveRecord::Migration[7.1]
  def change
    create_table :banners do |t|
      t.integer :entity_id, null: false
      t.string :entity_bundle
      t.string :headline
      t.string :alert_type
      t.boolean :show_close
      t.text :content
      t.jsonb :context
      t.boolean :operating_status_cta
      t.boolean :email_updates_button
      t.boolean :find_facilities_cta
      t.boolean :limit_subpage_inheritance

      t.timestamps
    end
    add_index :banners, :entity_id
  end
end
