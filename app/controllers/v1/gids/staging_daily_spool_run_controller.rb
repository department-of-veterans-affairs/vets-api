# frozen_string_literal: true

# This is a utility controller for running daily spool files. It is only used in the staging and
# lower environments as a way of manually running the daily spool files. Invoking it from production
# should have no effect as it checks for that and returns immediately if true.
module V1
  module GIDS
    class StagingDailySpoolRunController < GIDSController
      def index
        return if Settings.vsp_environment.eql?('production')

        # Delete all records for today so that it will run.
        SpoolFileEvent.where('DATE(successful_at) = ?', Date.current).delete_all

        EducationForm::CreateDailySpoolFiles.new.perform
      end
    end
  end
end
