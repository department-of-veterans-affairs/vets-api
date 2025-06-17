class RenameAuditUserIdentifierTypeEnumOption < ActiveRecord::Migration[7.2]
  def up
    safety_assured do
      execute <<-SQL
        ALTER TYPE audit_user_identifier_types RENAME VALUE 'system_hostmame' TO 'system_hostname';
      SQL
    end
  end

  def down
    safety_assured do
      execute <<-SQL
        ALTER TYPE audit_user_identifier_types RENAME VALUE 'system_hostname' TO 'system_hostmame';
      SQL
    end
  end
end
