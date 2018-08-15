class CreatePost911NotFoundErrors < ActiveRecord::Migration
  def change
    create_table :post911_not_found_errors do |t|
      t.uuid :user_uuid, null: false
      t.string :encrypted_user_json, null: false
      t.string :encrypted_user_json_iv, null: false
      t.timestamp :request_timestamp, null: false
      t.timestamps(null: false)
    end
  end
end
