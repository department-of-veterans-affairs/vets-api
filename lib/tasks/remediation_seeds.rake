# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc 'Load remediation seeds for simple_forms_api development and testing'
    task remediation: :environment do
      puts '[Seeds] Loading remediation seeds...'
      load Rails.root.join('db', 'seeds', 'remediation.rb')
      puts '[Seeds] Remediation seeds loaded.'
    end
  end
end
