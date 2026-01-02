class RemoveVSOGrpIndexAndAddUniqueIndex < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  class Rep < ActiveRecord::Base
    self.table_name = 'veteran_representatives'
  end

  def up
    remove_index :veteran_representatives,
                 name: :index_vso_grp,
                 if_exists: true,
                 algorithm: :concurrently

    dup_ids = Rep.group(:representative_id)
                 .having("COUNT(*) > 1")
                 .pluck(:representative_id)
    Rep.where(representative_id: dup_ids).delete_all if dup_ids.any?

    add_index :veteran_representatives,
              :representative_id,
              unique: true,
              name: :index_veteran_representatives_on_representative_id,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :veteran_representatives,
                 name: :index_veteran_representatives_on_representative_id,
                 if_exists: true,
                 algorithm: :concurrently

    add_index :veteran_representatives,
              %i[first_name last_name representative_id],
              name: :index_vso_grp,
              algorithm: :concurrently,
              if_not_exists: true
  end
end
