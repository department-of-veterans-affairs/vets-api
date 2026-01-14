# frozen_string_literal: true

class AddTokenToEducationBenefitsClaims < ActiveRecord::Migration[7.2]
  def change
    add_column :education_benefits_claims, :token, :string
  end
end
