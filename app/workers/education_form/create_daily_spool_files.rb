# frozen_string_literal: true
require 'net/sftp'
require 'iconv'

module EducationForm
  class CreateDailySpoolFiles
    include Sidekiq::Worker
    sidekiq_options queue: 'default',
                    retry: 5

    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"

    # Setting the default value to the `unprocessed` scope is safe
    # because the execution of the query itself is defered until the
    # data is accessed by the code inside of the method.
    # Be *EXTREMELY* careful running this manually as it may overwrite
    # existing files on the SFTP server if one was already written out
    # for the day.
    def perform(records: EducationBenefitsClaim.unprocessed)
      # Group the formatted records into different regions
      regional_data = group_submissions_by_region(records)
      # Create a remote file for each region, and write the records into them
      create_files(regional_data)
      true
    end

    def group_submissions_by_region(records)
      regional_data = Hash.new { |h, k| h[k] = [] }
      records.each do |record|
        region_key = record.regional_processing_office&.to_sym
        regional_data[region_key] << record
      end
      regional_data
    end

    def write_files(sftp: nil, structured_data:)
      structured_data.each do |region, records|
        region_id = EducationFacility.facility_for(region: region)
        filename = "#{region_id}_#{Time.zone.today.strftime('%m%d%Y')}_vetsgov.spl"
        log_submissions(records, filename, region_id)
        # create the single textual spool file
        contents = records.map do |record|
          format_application(record.open_struct_form)
        end.join(WINDOWS_NOTEPAD_LINEBREAK)

        if sftp
          sftp.upload!(StringIO.new(contents), filename)
        else
          dir_name = Rails.root.join('tmp', 'spool_files')
          FileUtils.mkdir_p(dir_name)
          File.open(File.join(dir_name, filename), 'w') do |f|
            f.write(contents)
          end
        end

        # mark the records as processed once the file has been written
        records.each { |r| r.update_attribute(:processed_at, Time.zone.now) }
      end
    end

    def create_files(structured_data)
      logger.error('No applications to write') && return if structured_data.empty?
      if Rails.env.development? || ENV['EDU_SFTP_HOST'].blank?
        write_files(structured_data: structured_data)
      elsif ENV['EDU_SFTP_PASS'].blank?
        raise "EDU_SFTP_PASS not set for #{ENV['EDU_SFTP_USER']}@#{ENV['EDU_SFTP_HOST']}"
      else
        Net::SFTP.start(ENV['EDU_SFTP_HOST'], ENV['EDU_SFTP_USER'], password: ENV['EDU_SFTP_PASS']) do |sftp|
          logger.info('Connected to SFTP')
          write_files(sftp: sftp, structured_data: structured_data)
        end
        logger.info('Disconnected from SFTP')
      end
    end

    # Convert the JSON document into the text format that we submit to the backend
    def format_application(form)
      EducationForm::Forms::Base.build(form).format
    rescue => e
      logger.error("Could not format #{form.confirmation_number}")
      raise e
    end

    private

    def log_submissions(records, filename, region_id)
      logger.info("Writing #{records.count} application(s) to #{filename}")
      logger.info("IDs: #{records.map(&:id)}")
      StatsD.gauge('worker.education_benefits_claim.transmissions', records.count, tags:
        { rpo: region_id })
    end
  end
end
