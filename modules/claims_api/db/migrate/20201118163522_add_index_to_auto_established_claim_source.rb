# frozen_string_literal: true

class AddIndexToAutoEstablishedClaimSource < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def change
    add_index :claims_api_auto_established_claims, :source, algorithm: :concurrently
  end
end
