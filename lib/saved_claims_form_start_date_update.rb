# TODO: Remove this file after the migration has been run
# frozen_string_literal: true

module DataMigrations
  module SavedClaimsFormStartDateUpdate
    module_function

    def run
      # default batch size is 1000
      SavedClaim.where.not(itf_datetime: nil).find_each do |claim|
        claim.update(form_start_date: claim.itf_datetime, itf_datetime: nil)
      end
    end
  end
end
