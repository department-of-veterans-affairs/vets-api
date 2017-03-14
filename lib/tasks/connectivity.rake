# frozen_string_literal: true

# Checks backend connectivity to the various VA machines. Run with
# `RAILS_ENV=production bundle exec rake connectivity:all`

# Allows running on development machines
Rails.logger = Logger.new('connectivity.log')

# For Rx/SM
REDIS_CONFIG = Rails.application.config_for(:redis).freeze
Redis.current = Redis.new(REDIS_CONFIG['redis'])

require 'evss/claims_service'
require 'facilities/async_client'
require 'gi/client'
require 'hca/configuration'
require 'hca/service'
require 'mvi/service'
require 'rx/client'
require 'sm/client'

namespace :connectivity do
  desc 'Create daily spool files'
  task all: [:edu, :evss, :gi, :hca, :mvi, :redis, :rx, :sm, :statsd, :vha]

  desc 'Check Edu SFTP'
  task edu: :environment do
    begin
      Net::SFTP.start(Settings.edu.sftp.host, Settings.edu.sftp.user, password: Settings.edu.sftp.pass)
      puts "Edu SFTP connection success for #{Settings.edu.sftp.host}."
    rescue => e
      puts "Edu SFTP connection unsuccessful for #{Settings.edu.sftp.host}!"
      puts " - Error encountered: `#{e}`"
    end
  end

  desc 'Check EVSS'
  task evss: :environment do
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

  desc 'Check GI'
  task gi: :environment do
    begin
      GI::Client.new.get_autocomplete_suggestions('university')
      puts "GIDS connection success for #{Settings.gids.url}."
    rescue => e
      puts "GIDS connection unsuccessful for #{Settings.gids.url}!"
      puts " - Error encountered: `#{e}`"
    end
  end

  desc 'Check HCA'
  task hca: :environment do
    begin
      HCA::Service.new.health_check
      puts "HCA connection success for #{Settings.hca.endpoint}."
    rescue => e
      puts "HCA connection unsuccessful for #{Settings.hca.endpoint}!"
      puts " - Error encountered: `#{e}`"
    end
  end

  desc 'Check MVI'
  task mvi: :environment do
    begin
      user = User.new(
        uuid: SecureRandom.uuid,
        first_name: 'Foo',
        middle_name: 'B',
        last_name: 'Fooman',
        birth_date: '1901-01-01',
        gender: 'M',
        ssn: '111221122',
        email: 'foo@bar.com',
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      )
      user.va_profile
      puts "MVI connection success for #{Settings.mvi.url}."
    rescue => e
      puts "MVI connection unsuccessful for #{Settings.mvi.url}!"
      puts " - Error encountered: `#{e}`"
    end
  end

  desc 'Check Redis'
  task redis: :environment do
    begin
      Redis.current.get('asdf')
      puts "Redis connection success for #{Settings.redis.host}:#{Settings.redis.port}"
    rescue => e
      puts "Redis connection unsuccessful for #{Settings.redis.host}:#{Settings.redis.port}"
      puts " - Error encountered: `#{e}`"
    end
  end

  desc 'Check Rx'
  task rx: :environment do
    begin
      Rx::Client.new(session: { user_id: '12210827' }).authenticate
      puts "Rx connection success for #{Settings.mhv.rx.host}."
    rescue => e
      puts "Rx connection unsuccessful for #{Settings.mhv.rx.host}!"
      puts " - Error encountered: `#{e}`"
    end
  end

  desc 'Check SM'
  task sm: :environment do
    begin
      SM::Client.new(session: { user_id: '12210827' }).authenticate
      puts "SM connection success for #{Settings.mhv.sm.host}."
    rescue => e
      puts "SM connection unsuccessful for #{Settings.mhv.sm.host}!"
      puts " - Error encountered: `#{e}`"
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

  desc 'Check VHA'
  task vha: :environment do
    begin
      VHAFacilityAdapter.new.query([0, 0, 0, 0])
      puts "VHA connection success for #{Settings.locators.vha}."
    rescue => e
      puts "VHA connection unsuccessful for #{Settings.locators.vha}!"
      puts " - Error encountered: `#{e}`"
    end
  end
end
