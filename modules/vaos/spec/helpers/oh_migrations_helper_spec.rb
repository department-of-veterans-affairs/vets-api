# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::OhMigrationsHelper do
  it 'returns empty hash for nil' do
    Settings.mhv.oh_facility_checks.oh_migrations_list = nil
    expect(VAOS::OhMigrationsHelper.get_migrations).to eq({})
  end

  it 'calculates future migration dates' do
    go_live_date = Time.zone.today + 7.days
    Settings.mhv.oh_facility_checks.oh_migrations_list = "#{go_live_date}:[123,Test 1]"

    migrations = VAOS::OhMigrationsHelper.get_migrations

    expect(migrations.size).to eq(1)
    expect(migrations).to have_key('123')
    expect(migrations['123'][:migration_days]).to eq(-7)
    expect(migrations['123'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['123'][:migration_date]).to eq(go_live_date)
    expect(migrations['123'][:disable_eligibility]).to be(true)
  end

  it '30 days before migration date, eligibility is disabled' do
    go_live_date = Time.zone.today + 30.days
    Settings.mhv.oh_facility_checks.oh_migrations_list = "#{go_live_date}:[123,Test 1]"
    migrations = VAOS::OhMigrationsHelper.get_migrations

    expect(migrations.size).to eq(1)
    expect(migrations).to have_key('123')
    expect(migrations['123'][:migration_days]).to eq(-30)
    expect(migrations['123'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['123'][:migration_date]).to eq(go_live_date)
    expect(migrations['123'][:disable_eligibility]).to be(true)
  end

  it '6 days after migration date, eligibility is still disabled' do
    go_live_date = Time.zone.today - 6.days
    Settings.mhv.oh_facility_checks.oh_migrations_list = "#{go_live_date}:[123,Test 1]"
    migrations = VAOS::OhMigrationsHelper.get_migrations

    expect(migrations.size).to eq(1)
    expect(migrations).to have_key('123')
    expect(migrations['123'][:migration_days]).to eq(6)
    expect(migrations['123'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['123'][:migration_date]).to eq(go_live_date)
    expect(migrations['123'][:disable_eligibility]).to be(true)
  end

  it '7 days after migration date, eligibility is not disabled' do
    go_live_date = Time.zone.today - 7.days
    Settings.mhv.oh_facility_checks.oh_migrations_list = "#{go_live_date}:[123,Test 1]"
    migrations = VAOS::OhMigrationsHelper.get_migrations

    expect(migrations.size).to eq(1)
    expect(migrations).to have_key('123')
    expect(migrations['123'][:migration_days]).to eq(7)
    expect(migrations['123'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['123'][:migration_date]).to eq(go_live_date)
    expect(migrations['123'][:disable_eligibility]).to be(false)
  end

  it 'calculates past migration dates' do
    go_live_date = Time.zone.today - 60.days
    Settings.mhv.oh_facility_checks.oh_migrations_list = "#{go_live_date}:[123,Test 1]"
    migrations = VAOS::OhMigrationsHelper.get_migrations

    expect(migrations.size).to eq(1)
    expect(migrations).to have_key('123')
    expect(migrations['123'][:migration_days]).to eq(60)
    expect(migrations['123'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['123'][:migration_date]).to eq(go_live_date)
    expect(migrations['123'][:disable_eligibility]).to be(false)
  end

  it 'handles multiple migrations' do
    go_live_date1 = Time.zone.today + 7.days
    go_live_date2 = Time.zone.today - 60.days

    oh_migrations_list = "#{go_live_date1}:[123,Test 1],[456,Test 2];#{go_live_date2}:[518,Cleveland VA]"
    Settings.mhv.oh_facility_checks.oh_migrations_list = oh_migrations_list

    migrations = VAOS::OhMigrationsHelper.get_migrations

    expect(migrations.size).to eq(3)
    expect(migrations).to have_key('123')
    expect(migrations['123'][:migration_days]).to eq(-7)
    expect(migrations['123'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['123'][:migration_date]).to eq(go_live_date1)
    expect(migrations['123'][:disable_eligibility]).to be(true)
    expect(migrations).to have_key('456')
    expect(migrations['456'][:migration_days]).to eq(-7)
    expect(migrations['456'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['456'][:migration_date]).to eq(go_live_date1)
    expect(migrations['456'][:disable_eligibility]).to be(true)
    expect(migrations).to have_key('518')
    expect(migrations['518'][:migration_days]).to eq(60)
    expect(migrations['518'][:migration_date]).to be_an_instance_of(Date)
    expect(migrations['518'][:migration_date]).to eq(go_live_date2)
    expect(migrations['518'][:disable_eligibility]).to be(false)
  end
end
