# frozen_string_literal: true

class AddSpecialIssuesToAutoEstablishedClaim < ActiveRecord::Migration[6.0]
  def change
    add_column :claims_api_auto_established_claims, :special_issues, :jsonb, default: []
  end
end
