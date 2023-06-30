class AddRefreshTokenPathToClientConfig < ActiveRecord::Migration[6.1]
  def change
    add_column :client_configs, :refresh_token_path, :string
  end
end
