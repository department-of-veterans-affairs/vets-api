class AddTransactionIdToAutoEstablishedClaim < ActiveRecord::Migration[7.1]
  def change
    add_column :claims_api_auto_established_claims, :transaction_id, :string, default: nil
  end
end
