class AddLockedToUserVerifications < ActiveRecord::Migration[6.1]
  def change
    add_column :user_verifications, :locked, :boolean, null: false, default: false
  end
end
