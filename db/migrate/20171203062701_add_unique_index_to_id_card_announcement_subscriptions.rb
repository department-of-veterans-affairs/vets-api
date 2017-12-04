class AddUniqueIndexToIdCardAnnouncementSubscriptions < ActiveRecord::Migration
  disable_ddl_transaction!

  def change
    add_index :id_card_announcement_subscriptions, :email, unique: true, algorithm: :concurrently
  end
end
