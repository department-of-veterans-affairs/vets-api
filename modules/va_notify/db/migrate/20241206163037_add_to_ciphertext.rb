class AddToCiphertext < ActiveRecord::Migration[7.1]
  def change
    add_column :va_notify_notifications, :to_ciphertext, :text
    add_column :va_notify_notifications, :encrypted_kms_key, :text
  end
end
