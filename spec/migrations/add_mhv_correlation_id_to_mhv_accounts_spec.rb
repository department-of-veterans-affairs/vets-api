require 'rails_helper.rb'
require Rails.root.join('db/migrate/20180503081144_add_mhv_correlation_id_to_mhv_accounts.rb')
require Rails.root.join('db/migrate/20180503172030_add_indexes_for_mhv_accounts.rb')

describe 'MHVAccountMigrationTest', type: :migration do
  MIGRATIONS_PATH     = Rails.root.join('db/migrate')
  PRISTINE_VERSION    = 20180423182604
  ADD_COLUMN_VERSION  = 20180503081144
  ADD_INDEXES_VERSION = 20180503172030

  before(:each) do
    # MANUALLY do the following to get to the version before migrations:
    # in config/environments/test.rb ADD config.active_record.migration_error = false
    # in rails_helper COMMENT out ActiveRecord::Migration.maintain_test_schema!
    # bundle exec rake db:drop
    # bundle exec rake db:create
    # bundle exec rake db:migrate VERSION=20180423182604
    # Persist some data
    MhvAccount.reset_column_information
    1000.times do
      time = Time.current
      user = create(:user, uuid: SecureRandom.uuid)
      allow(user).to receive(:mhv_correlation_id).and_return(SecureRandom.uuid)
      attributes = { user_uuid: user.uuid, account_state: 'upgraded', registered_at: time, upgraded_at: time }
      mhv_account = MhvAccount.find_or_initialize_by(attributes)
      mhv_account.save
    end
  end

  describe 'up add column version' do
    # Migrate to the Migration Under Test (MUT)
    ActiveRecord::Migrator.migrate(MIGRATIONS_PATH, ADD_COLUMN_VERSION)
    # Reset column info of relevant tables
    MhvAccount.reset_column_information

    xit 'migrates without data loss' do
      expect(MhvAccount.column_names).to include('mhv_correlation_id')
      t1 = Time.now
      MhvAccount.all
      t2 = Time.now
      puts (t2 - t1)
      expect(t2 - t1).to be < 1
    end
  end

  describe 'up add indexes version' do
    # Migrate to the Migration Under Test (MUT)
    ActiveRecord::Migrator.migrate(MIGRATIONS_PATH, ADD_INDEXES_VERSION)
    # Reset column info of relevant tables
    MhvAccount.reset_column_information

    xit 'migrates without data loss' do
      expect(MhvAccount.column_names).to include('mhv_correlation_id')
      t1 = Time.now
      MhvAccount.all
      t2 = Time.now
      puts (t2 - t1)
      expect(t2 - t1).to be < 1
    end
  end
end
