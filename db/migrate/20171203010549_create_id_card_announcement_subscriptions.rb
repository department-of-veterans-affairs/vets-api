class CreateIdCardAnnouncementSubscriptions < ActiveRecord::Migration
  def change
    create_table :id_card_announcement_subscriptions do |t|
      t.string :email, null: false, unique: true
      t.timestamps null: false
    end
  end
end
