# frozen_string_literal: true

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
    Veteran::Service::Representative.create(
      poa_code: ['083'],
      first_name: 'Tamara',
      last_name: 'Ellis',
      email: 'va.api.user+idme.001@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa_code: ['074'],
      first_name: 'John',
      last_name: 'Doe',
      email: 'va.api.user+idme.007@gmail.com'
    )
  end
end
