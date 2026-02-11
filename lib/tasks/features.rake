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
        Rails.logger.info('features:setup running in dry-run mode in production')
        Rails.logger.info('FORCE=true or user confirmation will be required to make changes')
      else
        raise 'Running features:setup in production non-interactively requires FORCE=true' unless $stdin.tty?

        puts 'You are running features:setup in production. This will modify Flipper features in the database.'
        puts 'The following changes will be made:'
        result = Flipper::Utilities.setup_features(Flipper, dry_run: true)
        sleep 0.1
        puts "- Features to be added: #{result[:added].count} (#{result[:added].join(', ')})" if result[:added].any?
        if result[:enabled].any?
          puts "- Features to be enabled: #{result[:enabled].count} (#{result[:enabled].join(', ')})"
        end
        if result[:removed].any?
          puts "- Features to be removed: #{result[:removed].count} (#{result[:removed].join(', ')})"
        end
        if result[:added].empty? && result[:enabled].empty? && result[:removed].empty?
          puts 'No changes to be made.'
          next
        end
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
    is_pg = %w[PostgreSQL PostGIS].include?(conn.adapter_name)
    if !dry_run && is_pg
      lock = conn.select_value("SELECT pg_try_advisory_lock(#{lock_key})")
      locked = ['t', true].include?(lock)
      unless locked
        Rails.logger.warn('features:setup - could not obtain advisory lock, another process may be running this task')
        next
      end
    end

    begin
      message = 'features:setup'
      if dry_run
        # Simulate changes without modifying DB
        result = Flipper::Utilities.setup_features(Flipper, dry_run: true)
        message += ' dry-run'
        message += " - would add: #{result[:added].count},"
        message += " enable: #{result[:enabled].count}, remove: #{result[:removed].count}"
      else
        ActiveRecord::Base.transaction do
          result = Flipper::Utilities.setup_features(Flipper)
        end
        message += ' completed'
        message += " - added: #{result[:added].count},"
        message += " enabled: #{result[:enabled].count}, removed: #{result[:removed].count}"
      end
      Rails.logger.warn(message)
    ensure
      conn.execute("SELECT pg_advisory_unlock(#{lock_key})") if locked && is_pg
    end
  end
end
