# frozen_string_literal: true

class AddMd5ToClaimsApiAutoEstablishedClaims < ActiveRecord::Migration[4.2]
  def change
    add_column :claims_api_auto_established_claims, :md5, :string
  end
end
