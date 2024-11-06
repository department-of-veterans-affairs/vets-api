# frozen_string_literal: true

module Pensions
  module DataMigrations
    module SavedClaimsFormStartDateUpdate
      module_function

      def run
        # default batch size is 1000
        puts 'Migrating data from deprecated itf_datetime column to form_start_date'
        total = 0
        SavedClaim.where.not(itf_datetime: nil).find_each do |claim|
          claim.update(form_start_date: claim.itf_datetime, itf_datetime: nil)
          total += 1
        end
        puts "Migrated #{total} records"
      end
    end
  end
end
