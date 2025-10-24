# frozen_string_literal: true

require_relative 'seed/records'

namespace :accredited_representative_portal do
  desc <<~MSG.squish
    Seeds accredited representative and POA request records
  MSG
  task setup_staging_users: :environment do
    unless ENV['APPLICATION_ENV'] == 'staging'
      Rails.logger.warn(<<~MSG.squish)
        Whoops! This task can only be run in the staging environment.
        Stopping now.
      MSG

      exit!(1)
    end

    config = Settings.accredited_representative_portal.allow_list.github

    client =
      Octokit::Client.new(
        api_endpoint: config.base_uri,
        access_token: config.access_token
      )

    csv = client
          .contents(config.repo, path: config.path)
          .then { |contents| Base64.decode64(contents[:content]) }
          .then { |content| CSV.parse(content, headers: true) }

    records = csv.map(&:to_h)

    results = {}.tap do |result|
      result[:not_found_count] = 0
      result[:updated_count] = 0
      result[:error_count] = 0

      records.map(&:to_h).map do |attributes|
        rep = Veteran::Service::Representative.find_by(representative_id: attributes['representative_id'])
        if rep
          rep.user_types = [attributes['user_type']]
          rep.email = attributes['email']
          rep.poa_codes = [attributes['poa_code_1'], attributes['poa_code_2']].compact
          begin
            rep.save!
            result[:updated_count] += 1
          rescue => e
            result[:error_count] += 1
            Rails.logger.info(e)
          end
        else
          result[:not_found_count] += 1
          Rails.logger.info("Could not find Veteran::Service::Representative #{attributes['representative_id']}")
        end
      end
    end

    Rails.logger.info('Updated ARP staging representatives:')
    Rails.logger.info(results)
  end
end
