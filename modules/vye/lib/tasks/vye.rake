# frozen_string_literal: true

namespace :vye do
  namespace :nonprod do
    desc 'Seed with fake data for dev, sandbox, and staging'
    task seed: :environment do |_cmd, _args|
      team_sensitive_root = Rails.root / '../va.gov-team-sensitive'
      tu = CSV.read(team_sensitive_root / 'Administrative/vagov-users/test_users.csv', headers: true)
      su = CSV.read(team_sensitive_root / 'Administrative/vagov-users/mvi-staging-users.csv', headers: true)
  
      result = Hash.new { |h, k| h[k] = []}
      
      result = tu.each_with_object(result) do |u, a|
        (key, ssn) = 2.times.map { u['ssn'].strip } if String === u['ssn']
        idme_uuid = u['idme_uuid'].strip if String === u['idme_uuid']
        email = u['email'].strip if String === u['email']
        full_name = u.values_at('first_name', 'middle_name', 'last_name').compact.map(&:strip).map(&:capitalize).join(' ')

        next if key.blank?
        next if a[key].last.present? && a[key].last[:idme_uuid] == idme_uuid && a[key].last[:email] == email

        a[key].push({ full_name: full_name, ssn: ssn, idme_uuid: idme_uuid, email: email})
      end

      result = su.each_with_object(result) do |u, a|
        key = u['ssn'].strip if String === u['ssn']
        icn = u['icn'].strip if String === u['icn']
        full_name = u.values_at('first_name', 'middle_name', 'last_name').compact.map(&:strip).map(&:capitalize).join(' ')

        next if a[key].blank? || key.blank? || icn.blank?

        case
        when a[key].all? { |v| v.key?(:icn) == false }
          a[key].each { |v| v[:icn] = icn }
        when a[key].any? { |v| v.key?(:icn) && v[:icn] != icn }
          raise "ssn_with_multiple_icn"
        when a[key].all? { |v| v.key?(:icn) && v[:icn] == icn }
          next
        else
        end
      end

      puts result.values.select { |users| users.present? && users.all? { |u| u.key?(:icn) } }.to_yaml
    end
  end

  namespace :install do
    desc 'Installs config into config/settings.local.yml'
    task config: :environment do |_cmd, _args|
      engine_dev_path = Vye::Engine.root / 'config/settings.local.yml'
      local_path = Rails.root / 'config/settings.local.yml'
      local_settings = Config.load_files(local_path)

      raise "Vye config already exists in #{local_path}" if local_settings.vye

      local_path.write(engine_dev_path.read, mode: 'a')
    end
  end
end
