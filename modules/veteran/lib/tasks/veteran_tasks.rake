# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :veteran do
  desc 'Reload VSO Information'
  task reload_vso_data: :environment do
    puts 'Loading VSO data from OGC'
    Veteran::VsoReloader.perform_async
    puts "#{Veteran::Service::Organization.count} Organizations loaded"
    puts "#{Veteran::Service::Representative.count} Representatives loaded"
  end

  desc 'Load sample data for VSO Reps and Orgs'
  task load_sample_vso_data: :environment do
    Veteran::Service::Organization.create(poa: '074', name: '074 - AMERICAN LEGION')
    Veteran::Service::Organization.create(poa: '083', name: '083 - DISABLED AMERICAN VETERANS')
    Veteran::Service::Organization.create(poa: '095', name: '095 - ITALIAN AMERICAN WAR VETERANS OF THE US, INC.')
    Veteran::Service::Organization.create(poa: '1NY', name: '1NY - SAMANTHA Y WARSHAUER')
    Veteran::Service::Representative.create(
      poa_codes: %w[A1Q 095 074 083 1NY],
      first_name: 'Tamara',
      last_name: 'Ellis',
      email: 'va.api.user+idme.001@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa_codes: %w[A1Q 095 074 083 1NY],
      first_name: 'John',
      last_name: 'Doe',
      email: 'va.api.user+idme.007@gmail.com'
    )
  end
end
# rubocop:enable Metrics/BlockLength
