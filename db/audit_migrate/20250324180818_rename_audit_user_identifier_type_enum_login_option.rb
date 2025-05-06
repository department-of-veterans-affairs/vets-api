class RenameAuditUserIdentifierTypeEnumLoginOption < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      execute <<-SQL
        ALTER TYPE audit_user_identifier_types RENAME VALUE 'login_uuid' TO 'logingov_uuid';
      SQL
    end
  end

  def down
    safety_assured do
      execute <<-SQL
        ALTER TYPE audit_user_identifier_types RENAME VALUE 'logingov_uuid' TO 'login_uuid';
      SQL
    end
  end
end
