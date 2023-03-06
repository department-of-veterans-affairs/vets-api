class AddWebLogoutToClientConfig < ActiveRecord::Migration[6.1]
  def change
    safety_assured do
      add_column :client_configs, :logout_redirect_uri, :text
    end
  end
end
