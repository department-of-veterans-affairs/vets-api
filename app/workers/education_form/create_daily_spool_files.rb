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
      return false if federal_holiday?
      # Group the formatted records into different regions
      regional_data = group_submissions_by_region(records)
      # Create a remote file for each region, and write the records into them
      create_files(regional_data)
      true
    end

    def group_submissions_by_region(records)
      records.group_by { |r| r.regional_processing_office.to_sym }
    end

    def write_files(sftp: nil, structured_data:)
      structured_data.each do |region, records|
        region_id = EducationFacility.facility_for(region: region)
        filename = "#{region_id}_#{Time.zone.today.strftime('%m%d%Y')}_vetsgov.spl"
        log_submissions(records, filename)
        # create the single textual spool file
        contents = records.map do |record|
          format_application(record.open_struct_form, rpo: region_id)
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
        # track and update the records as processed once the file has been successfully written
        track_submissions(region_id)
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
    def format_application(data, rpo: 0)
      form = EducationForm::Forms::Base.build(data)
      # TODO(molson): Once we have a column in the db with the form type, we can move
      # this tracking code to somewhere more reasonable.
      track_form_type(form.class::TYPE, rpo)
      form.format
    rescue => e
      logger.error("Could not format #{form.confirmation_number}")
      raise e
    end

    private

    def federal_holiday?
      holiday = Holidays.on(Time.zone.today, :us, :observed)
      if holiday.empty?
        false
      else
        logger.info("Skipping on a Holiday: #{holiday.first[:name]}")
        true
      end
    end

    # Useful for debugging which records were or were not sent over successfully,
    # in case of network failures.
    def log_submissions(records, filename)
      logger.info("Writing #{records.count} application(s) to #{filename}")
      logger.info("IDs: #{records.map(&:id)}")
    end

    # Useful for alerting and monitoring the numbers of successfully send submissions
    # per-rpo, rather than the number of records that were *prepared* to be sent.
    def track_submissions(region_id)
      stats[region_id].each do |type, count|
        StatsD.gauge('worker.education_benefits_claim.transmissions',
                     count,
                     tags: { rpo: region_id,
                             form: type })
      end
    end

    def track_form_type(type, rpo)
      stats[rpo][type] += 1
    end

    def stats
      @stats ||= Hash.new(Hash.new(0))
    end
  end
end
