# frozen_string_literal: true

module DataMigrations
  module InProgressFormStatusDefault
    module_function

    def run
      InProgressForm.where(status: nil).update_all(status: 'pending') # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
