# frozen_string_literal: true

class ValidateOrgRepForeignKeys < ActiveRecord::Migration[7.1]
  def change
    validate_foreign_key :accredited_organization_accredited_representatives, :accredited_representatives
    validate_foreign_key :accredited_organization_accredited_representatives, :accredited_organizations
  end
end
