# frozen_string_literal: true

class AddEVSSResponseTo526 < ActiveRecord::Migration[5.2]
  def change
    add_column :claims_api_auto_established_claims, :encrypted_evss_response, :string
    add_column :claims_api_auto_established_claims, :encrypted_evss_response_iv, :string
  end
end
