class DropPensionIpfNotifications < ActiveRecord::Migration[7.1]
  def change
    drop_table :pension_ipf_notifications, if_exists: true
  end
end
