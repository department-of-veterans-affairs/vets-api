class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_enum :audit_user_identifier_types, %w[icn login_uuid idme_uuid mhv_id dslogon_id system_hostmame]

    create_table :logs do |t|
      t.string :subject_user_identifier, null: false, index: true
      t.enum :subject_user_identifier_type, enum_type: :audit_user_identifier_types, null: false
      t.string :acting_user_identifier, null: false, index: true
      t.enum :acting_user_identifier_type, enum_type: :audit_user_identifier_types, null: false
      t.string :event_id, null: false, index: true
      t.string :event_description, null: false
      t.string :event_status, null: false
      t.datetime :event_occurred_at, null: false
      t.jsonb :message, null: false
      t.timestamps
    end
  end
end
