class RemoveMd5Columns < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      remove_index :claims_api_power_of_attorneys,
                  column: :header_md5,
                  name: "index_claims_api_power_of_attorneys_on_header_md5",
                  if_exists: true,
                  algorithm: :concurrently

      remove_index :claims_api_auto_established_claims,
                  column: :md5,
                  name: "index_claims_api_auto_established_claims_on_md5",
                  if_exists: true,
                  algorithm: :concurrently

      remove_column :claims_api_power_of_attorneys, :md5, :string
      remove_column :claims_api_power_of_attorneys, :header_md5, :string
      remove_column :claims_api_auto_established_claims, :md5, :string
    end
  end
end