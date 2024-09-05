class CreateAccreditations < ActiveRecord::Migration[7.1]
  def change
    create_table :accreditations, id: :uuid do |t|
      t.references :accredited_individual, type: :uuid, foreign_key: true, null: false
      t.references :accredited_organization, type: :uuid, foreign_key: true, null: false
      t.boolean :can_accept_reject_poa
      t.timestamps

      t.index %i[ accredited_individual_id accredited_organization_id ], name: 'index_accreditations_on_indi_and_org_ids', unique: true
    end
  end
end
