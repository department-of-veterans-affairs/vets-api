# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
namespace :veteran do
  desc 'Load sample data for VSO Reps and Orgs'
  task load_sample_vso_data: :environment do
    Veteran::Service::Organization.create(poa: '074', name: '074 - AMERICAN LEGION')
    Veteran::Service::Organization.create(poa: '083', name: '083 - DISABLED AMERICAN VETERANS')
    Veteran::Service::Organization.create(poa: '095', name: '095 - ITALIAN AMERICAN WAR VETERANS OF THE US, INC.')
    Veteran::Service::Organization.create(poa: '1NY', name: '1NY - SAMANTHA Y WARSHAUER')
    Veteran::Service::Representative.create(
      poa: '1NY',
      first_name: 'Hector',
      last_name: 'Allen',
      email: 'vets.gov.user+0@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa: '074',
      first_name: 'Greg',
      last_name: 'Anderso',
      email: 'vets.gov.user+1@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa: '083',
      first_name: 'Andrea',
      last_name: 'Mitchel',
      email: 'vets.gov.user+2@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa: '095',
      first_name: 'Kenneth',
      last_name: 'Andrew',
      email: 'vets.gov.user+3@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa: '074',
      first_name: 'Alfred',
      last_name: 'Armstrong',
      email: 'vets.gov.user+4@gmail.com'
    )
    Veteran::Service::Representative.create(
      poa: '083',
      first_name: 'Frank',
      last_name: 'Lee',
      email: 'vets.gov.user+5@gmail.com'
    )
  end
end
# rubocop:enable Metrics/BlockLength
