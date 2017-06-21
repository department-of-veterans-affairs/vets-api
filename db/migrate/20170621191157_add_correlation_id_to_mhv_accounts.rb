class AddCorrelationIdToMhvAccounts < ActiveRecord::Migration
  def change
    add_column :mhv_accounts, :mhv_correlation_id, :string
  end
end
