class AddMissingIndexes < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :async_transactions, :created_at, algorithm: :concurrently
    add_index :base_facilities, :lat, algorithm: :concurrently
    add_index :claims_api_auto_established_claims, :evss_id, algorithm: :concurrently
    add_index :claims_api_auto_established_claims, :md5, algorithm: :concurrently
    add_index :education_benefits_submissions, :created_at, algorithm: :concurrently
    add_index :evss_claims, :evss_id, algorithm: :concurrently
    add_index :evss_claims, :updated_at, algorithm: :concurrently
    add_index :mhv_accounts, :mhv_correlation_id, algorithm: :concurrently
  end
end
