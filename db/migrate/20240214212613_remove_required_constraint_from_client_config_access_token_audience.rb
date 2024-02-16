class RemoveRequiredConstraintFromClientConfigAccessTokenAudience < ActiveRecord::Migration[7.0]
  def change
    change_column_null :client_configs, :access_token_audience, true
  end
end
