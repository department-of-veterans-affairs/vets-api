class CreateIdCardAnnouncementSubscriptions < ActiveRecord::Migration[4.2]
  def change
    create_table :id_card_announcement_subscriptions do |t|
      t.string :email, null: false
      t.timestamps null: false
    end
  end
end
