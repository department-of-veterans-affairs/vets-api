# frozen_string_literal: true

# :nocov:
module DataMigrations
  module InProgressFormInitialExpiration
    module_function

    def run
      rows_affected = 0

      InProgressForm.where(expires_at: nil).find_each do |form|
        form.expires_at = Time.current + 60.days
        form.save!
        rows_affected += 1
      end

      rows_affected
    end
  end
end
# :nocov:
