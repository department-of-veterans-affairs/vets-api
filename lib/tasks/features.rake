# frozen_string_literal: true

require 'zlib'
require 'flipper'
require 'flipper/utilities/bulk_feature_manager'

namespace :features do
  desc 'List current Flipper features and their states'
  task list: :environment do
    puts 'Current Flipper Features:'
    Flipper.features.each do |feature|
      state = if Flipper.enabled?(feature.name)
                'ENABLED'
              else
                'disabled'
              end
      puts "- #{feature.name}: #{state}"
    end
  end

  desc 'Setup Flipper features from config/features.yml (adds missing features, removes orphaned features)'
  task setup: :environment do
    conn = ActiveRecord::Base.connection
    locked = false
    if %w[PostgreSQL PostGIS].include?(conn.adapter_name)
      lock_key = Zlib.crc32('features:setup')
      lock = conn.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
      locked = ['t', true].include?(lock)
      unless locked
        Rails.logger.warn('features:setup - could not obtain advisory lock, another process may be running this task')
        next
      end
    else
      Rails.logger.warn('features:setup - advisory locks are only supported on PostgreSQL, skipping lock')
    end
    ActiveRecord::Base.transaction do
      Flipper::Utilities.setup_features
    end
  ensure
    if locked
      conn.execute <<~SQL.squish
        SELECT pg_advisory_unlock(#{lock_key})
      SQL
    end
  end
end
