# frozen_string_literal: true

require 'net/sftp'
require 'covid_vaccine/v0/expanded_registration_submission_csv_generator'

module CovidVaccine
  module V0
    class EnrollmentService
      def initialize(records)
        @records = records
        @io = ExpandedRegistrationSubmissionCSVGenerator.new(@records).io
      end

      attr_reader :records, :io
      
      def send_enrollment_file(file_name_suffix: '')
        file_name = generated_file_name + file_name_suffix

        Net::SFTP.start(sftp_host, sftp_username, password: sftp_password) do |sftp|
          sftp.upload!(@io, remote_file_path(file_name), name: file_name, progress: EnrollmentHandler.new)
        end
      end

      private

      def remote_file_path(name)
        "/#{name}"
      end

      def generated_file_name
        "#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_saves_lives_act_#{@records.size}_records.txt"
      end

      def sftp_host
        Settings.covid_vaccine.enrollment_service.sftp.host
      end

      def sftp_username
        Settings.covid_vaccine.enrollment_service.sftp.username
      end

      def sftp_password
        Settings.covid_vaccine.enrollment_service.sftp.password
      end
    end
  end
end