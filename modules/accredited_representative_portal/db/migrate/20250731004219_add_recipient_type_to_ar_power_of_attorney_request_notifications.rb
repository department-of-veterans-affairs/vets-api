class AddRecipientTypeToArPowerOfAttorneyRequestNotifications < ActiveRecord::Migration[7.2]
  def change
    add_column :ar_power_of_attorney_request_notifications, :recipient_type, :string
  end
end
