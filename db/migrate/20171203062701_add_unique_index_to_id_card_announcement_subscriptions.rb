class AddUniqueIndexToIdCardAnnouncementSubscriptions < ActiveRecord::Migration[4.2]
  disable_ddl_transaction!

  def change
    add_index :id_card_announcement_subscriptions, :email, unique: true, algorithm: :concurrently
  end
end
