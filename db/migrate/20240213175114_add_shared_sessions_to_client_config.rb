class AddSharedSessionsToClientConfig < ActiveRecord::Migration[7.0]
  def change
    safety_assured { add_column :client_configs, :shared_sessions, :boolean, default: false, null: false }
  end
end
