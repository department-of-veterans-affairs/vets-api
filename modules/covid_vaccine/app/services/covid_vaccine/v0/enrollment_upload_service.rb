# frozen_string_literal: true

require 'net/sftp'
require 'covid_vaccine/v0/expanded_registration_submission_csv_generator'

module CovidVaccine
  module V0
    class EnrollmentUploadService
      def initialize(io, batch_id, record_count, prefix: 'DHS_load')
        @io = io
        @batch_id = batch_id
        @record_count = record_count
        @prefix = prefix
      end

      attr_reader :records, :io

      def upload
        file_name = generated_file_name

        Net::SFTP.start(sftp_host, sftp_username, password: sftp_password) do |sftp|
          sftp.upload!(@io, remote_file_path(file_name), name: file_name, progress: EnrollmentHandler.new)
        end
      end

      private

      def remote_file_path(name)
        "/#{name}"
      end

      def generated_file_name
        "#{@prefix}_#{batch_id}_SLA_#{@record_count}_records.txt"
        # "DHS_load_#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_SLA_#{@records.size}_records.txt"
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
