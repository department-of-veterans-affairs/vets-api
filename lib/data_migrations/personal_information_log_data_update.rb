# frozen_string_literal: true

module DataMigrations
  module PersonalInformationLogDataUpdate
    module_function

    def run
      Lockbox.migrate(PersonalInformationLog)
    end
  end
end
