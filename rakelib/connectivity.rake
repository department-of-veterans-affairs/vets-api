# frozen_string_literal: true

# Checks backend connectivity to the various VA machines. Run with
# `RAILS_ENV=production bundle exec rake connectivity:all`
# Also does sanity check to ensure that logs directory is writeable

# Allows running on development machines
Rails.logger = Logger.new(STDOUT)

# For Rx/SM
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
Redis.current = Redis.new(REDIS_CONFIG['redis'])

class ConnectivityError < StandardError; end

# Convenience function that runs a connectivity example and prints out
# success/error messages
def check(name, config)
  yield
  puts "#{name} connection success for #{config}."
rescue => e
  puts "#{name} connection unsuccessful for #{config}!"
  puts " - Error encountered: `#{e}`"
end

namespace :connectivity do
  desc 'Check connectivity to all backend services'
  task all: %i[db edu evss gi hca logs mvi redis rx sm statsd vha]

  desc 'Check DB'
  task db: :environment do
    check 'DB', Settings.database_url do
      EVSSClaim.all.length
    end
  end

  desc 'Check Edu SFTP'
  task edu: :environment do
    check 'Edu SFTP', Settings.edu.sftp.host do
      Net::SFTP.start(
        Settings.edu.sftp.host,
        Settings.edu.sftp.user,
        password: Settings.edu.sftp.pass,
        port: Settings.edu.sftp.port,
        non_interactive: true
      )
    end
  end

  desc 'Check EVSS'
  task evss: :environment do
    check 'EVSS', Settings.evss.url do
      begin
        EVSS::ClaimsService.new({}).all_claims
        # Should return an XML 403 response, which Faraday fails parsing,
        # since it expects JSON
        puts "EVSS connection super success for #{Settings.evss.url}!"
      rescue Faraday::ParsingError
        puts "EVSS connection success for #{Settings.evss.url}."
      rescue => e
        puts "EVSS connection unsuccessful for #{Settings.evss.url}!"
        puts " - Error encountered: `#{e}`"
      end
    end
  end

  desc 'Check GI'
  task gi: :environment do
    check 'GIDS', Settings.gids.url do
      GI::Client.new.get_autocomplete_suggestions('university')
    end
  end

  desc 'Check HCA'
  task hca: :environment do
    check 'HCA', Settings.hca.endpoint do
      HCA::Service.new.health_check
    end
  end

  desc 'Check that logs are writeable'
  task logs: :environment do
    if File.writable?(Rails.root.join('log'))
      puts 'Logging directory is writeable.'
    else
      puts 'Logging directory is not writeable!'
    end
  end

  desc 'Check MVI'
  task mvi: :environment do
    check 'MVI', Settings.mvi.url do
      user = User.new(
        first_name: 'John',
        last_name: 'Smith',
        middle_name: 'W',
        birth_date: '1945-01-25',
        gender: 'M',
        ssn: '555443333',
        email: 'foo@bar.com',
        uuid: SecureRandom.uuid,
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      )

      raise ConnectivityError if user.va_profile[:status] == 'SERVER_ERROR'
    end
  end

  desc 'Check Redis'
  task redis: :environment do
    check 'Redis', "#{Settings.redis.host}:#{Settings.redis.port}" do
      Redis.current.get('asdf')
    end
  end

  desc 'Check Rx'
  task rx: :environment do
    check 'Rx', Settings.mhv.rx.host do
      Rx::Client.new(session: { user_id: '12210827' }).authenticate
    end
  end

  desc 'Check SM'
  task sm: :environment do
    check 'SM', Settings.mhv.sm.host do
      SM::Client.new(session: { user_id: '12210827' }).authenticate
    end
  end

  desc 'Check StatsD'
  task statsd: :environment do
    if Settings.statsd.host.present? && Settings.statsd.port.present?
      puts "StatsD configured for #{Settings.statsd.host}:#{Settings.statsd.port}."
    else
      puts 'StatsD not configured!'
    end
  end
end
