# frozen_string_literal: true

class AddBGSResponsesColumnToAutoEstablishedClaims < ActiveRecord::Migration[6.0]
  def change
    add_column(:claims_api_auto_established_claims, :encrypted_bgs_flash_responses, :string)
    add_column(:claims_api_auto_established_claims, :encrypted_bgs_flash_responses_iv, :string)
  end
end
