# frozen_string_literal: true

class CreateAccreditedIndividualsAccreditedOrganizations < ActiveRecord::Migration[7.1]
  def change
    create_table :accredited_individuals_accredited_organizations do |t|
      t.references :accredited_individual, type: :uuid, foreign_key: true, null: false
      t.references :accredited_organization, type: :uuid, foreign_key: true, null: false
      t.index %i[ accredited_individual_id accredited_organization_id ], name: 'index_accredited_on_indi_and_org_ids', unique: true
    end
  end
end
