# frozen_string_literal: true

require 'net/sftp'
module CovidVaccine
  module V0
    class EnrollmentUploadService
      def initialize(io, file_name)
        @io = io
        @file_name = file_name
      end

      attr_reader :io, :file_name

      def upload
        Net::SFTP.start(sftp_host, sftp_username, password: sftp_password, port: sftp_port) do |sftp|
          sftp.upload!(@io, file_name, name: file_name, progress: EnrollmentHandler.new)
        end
      end

      private

      def sftp_host
        Settings.covid_vaccine.enrollment_service.sftp.host
      end

      def sftp_username
        Settings.covid_vaccine.enrollment_service.sftp.username
      end

      def sftp_password
        Settings.covid_vaccine.enrollment_service.sftp.password
      end

      def sftp_port
        Settings.covid_vaccine.enrollment_service.sftp.port
      end
    end
  end
end
