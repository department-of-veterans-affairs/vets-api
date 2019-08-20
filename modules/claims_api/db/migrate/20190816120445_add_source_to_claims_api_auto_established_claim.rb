# frozen_string_literal: true

class AddSourceToClaimsApiAutoEstablishedClaim < ActiveRecord::Migration[5.2]
  def change
    add_column :claims_api_auto_established_claims, :source, :string
  end
end
