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
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', nil))
    force = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FORCE', nil))

    if Rails.env.production? && !force
      if dry_run
        Rails.logger.info('features:setup running in dry-run mode in production; --force required to make changes')
      else
        raise 'Running features:setup in production non-interactively requires FORCE=true' unless $stdin.tty?

        puts 'You are running features:setup in production. This will modify Flipper features in the database.'
        print 'Type "yes" to proceed: '
        confirm = $stdin.gets&.strip
        unless confirm&.downcase == 'yes'
          puts 'Aborting features:setup'
          next
        end
      end
    end

    conn = ActiveRecord::Base.connection
    lock_key = Zlib.crc32('features:setup') & 0xffffffff

    # Acquire advisory lock only when performing changes (not for dry-run)
    locked = false
    if !dry_run && conn.adapter_name == 'PostgreSQL'
      lock = conn.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
      locked = ['t', true].include?(lock)
      unless locked
        Rails.logger.warn('features:setup - could not obtain advisory lock, another process may be running this task')
        next
      end
    end

    begin
      if dry_run
        # Simulate changes without modifying DB
        result = Flipper::Utilities.setup_features(Flipper, dry_run: true)
        Rails.logger.info("features:setup dry-run - would add: #{result[:added].count}, enable: #{result[:enabled].count}, remove: #{result[:removed].count}")
      else
        ActiveRecord::Base.transaction do
          result = Flipper::Utilities.setup_features(Flipper)
        end
        Rails.logger.info("features:setup completed - added: #{result[:added].count}, enabled: #{result[:enabled].count}, removed: #{result[:removed].count}")
      end
    ensure
      conn.execute("SELECT pg_advisory_unlock(#{lock_key})") if locked && conn.adapter_name == 'PostgreSQL'
    end
  end
end
