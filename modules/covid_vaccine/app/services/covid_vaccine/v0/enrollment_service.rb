# frozen_string_literal: true

require 'net/sftp'
require 'covid_vaccine/v0/expanded_registration_submission_csv_generator'

module CovidVaccine
  module V0

  class EnrollmentService
    def initialize
      @records ||= CovidVaccine::V0::ExpandedRegistrationSubmission.enrolled_us.order(:created_at)
      @timestamp ||= Time.now.utc.strftime('%Y%m%d%H%M%S')
    end
    
    def send_enrollment_csv
      Net::SFTP.start(sftp_host, sftp_username, :password => sftp_password) do |sftp|
        sftp.upload!(csv_as_IO, remote_file_path, name: file_name, progress: EnrollmentHandler.new) 
      end  
    end

    private

    def csv_as_IO
      @io ||= ExpandedRegistrationSubmissionCSVGenerator.new(@records).io
    end

    # TODO: TBD
    def remote_file_path
      '' + file_name
    end

    def file_name
      @timestamp + '_vaccine_enrollment.csv'
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
