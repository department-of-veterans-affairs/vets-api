class AddPreneedsAttachmentsTable < ActiveRecord::Migration
  def change
    create_table "preneed_attachments" do |t|
      t.timestamps(null: false)
      t.uuid('guid', null: false)
      t.string   "encrypted_file_data",    null: false
      t.string   "encrypted_file_data_iv", null: false
    end
  end
end
