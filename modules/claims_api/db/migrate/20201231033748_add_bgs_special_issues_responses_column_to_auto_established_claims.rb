# frozen_string_literal: true

class AddBGSSpecialIssuesResponsesColumnToAutoEstablishedClaims < ActiveRecord::Migration[6.0]
  def change
    add_column(:claims_api_auto_established_claims, :encrypted_bgs_special_issue_responses, :string)
    add_column(:claims_api_auto_established_claims, :encrypted_bgs_special_issue_responses_iv, :string)
  end
end
