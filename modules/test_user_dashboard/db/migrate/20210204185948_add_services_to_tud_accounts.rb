# frozen_string_literal: true

class AddServicesToTudAccounts < ActiveRecord::Migration[6.0]
  def change
    add_column :test_user_dashboard_tud_accounts, :services, :text
  end
end
