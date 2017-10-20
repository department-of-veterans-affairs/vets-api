# frozen_string_literal: true
require 'csv'

namespace :emis do
  desc 'Dump eMIS attributes for all users in mock MVI database'
  task :dump, [:ymlfile, :outfile] => [:environment] do |_, args|
    raise 'No input YAML provided' unless args[:ymlfile]
    outfile = args[:outfile] || 'emis_dump.csv.generated'
    vss = EMIS::VeteranStatusService.new
    mis = EMIS::MilitaryInformationService.new

    mock = YAML.load_file(args[:ymlfile])
    CSV.open(outfile, 'w') do |file|
      file << %w(name ssn edipi addressee veteran episodes)
      mock['find_candidate'].each do |ssn, user|
        is_veteran = false
        has_eps = false
        begin
          resp = vss.get_veteran_status(edipi: user[:edipi])
          is_veteran = any_veteran_indicator?(resp.items.first)
          ep_resp = mis.get_military_service_episodes(edipi: user[:edipi])
          has_eps = ep_resp.items.present?
        rescue StandardError
          is_veteran = false
          has_eps = false
        end
        has_addr = addressee?(user[:address])
        file << [user[:given_names][0], user[:family_name], ssn,
                 user[:edipi], has_addr, is_veteran, has_eps]
      end
    end
  end
end

def any_veteran_indicator?(item)
  item&.post911_deployment_indicator == 'Y' ||
    item&.post911_combat_indicator == 'Y' ||
    item&.pre911_deployment_indicator == 'Y'
end

def addressee?(addr)
  return false if addr.blank?
  return false if addr.country.blank?
  return false if addr.state.blank?
  true
end
