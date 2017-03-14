# frozen_string_literal: true
require 'net/sftp'
require 'iconv'

module EducationForm
  WINDOWS_NOTEPAD_LINEBREAK = "\r\n"

  class FormattingError < StandardError
  end

  class CreateDailySpoolFiles
    include Sidekiq::Worker
    sidekiq_options queue: 'default',
                    retry: 5

    # Setting the default value to the `unprocessed` scope is safe
    # because the execution of the query itself is defered until the
    # data is accessed by the code inside of the method.
    # Be *EXTREMELY* careful running this manually as it may overwrite
    # existing files on the SFTP server if one was already written out
    # for the day.
    def perform(records: EducationBenefitsClaim.unprocessed)
      return false if federal_holiday?
      # Group the formatted records into different regions
      if records.count.zero?
        logger.info('No records to process.')
        return true
      else
        logger.info("Processing #{records.count} application(s)")
      end
      regional_data = group_submissions_by_region(records)
      formatted_records = format_records(regional_data)
      # Create a remote file for each region, and write the records into them
      writer = EducationForm::Writer::Factory.get_writer.new(logger: logger)
      write_files(writer, structured_data: formatted_records)

      true
    end

    def group_submissions_by_region(records)
      records.group_by { |r| r.regional_processing_office.to_sym }
    end

    # Convert the records into instances of their form representation.
    # The conversion into 'spool file format' takes place here, rather
    # than when we're writing the files so we can hold the connection
    # open for a shorter period of time.
    def format_records(grouped_data)
      grouped_data.each do |region, v|
        region_id = EducationFacility.facility_for(region: region)
        grouped_data[region] = v.map do |record|
          format_application(record, rpo: region_id)
        end
      end
    end

    # Write out the combined spool files for each region along with recording
    # and tracking successful transfers.
    def write_files(writer, structured_data:)
      structured_data.each do |region, records|
        region_id = EducationFacility.facility_for(region: region)
        filename = "#{region_id}_#{Time.zone.today.strftime('%m%d%Y')}_vetsgov.spl"
        log_submissions(records, filename)
        # create the single textual spool file
        contents = records.map(&:text).join(EducationForm::WINDOWS_NOTEPAD_LINEBREAK)

        writer.write(contents, filename)

        # track and update the records as processed once the file has been successfully written
        track_submissions(region_id)
        records.each { |r| r.record.update_attribute(:processed_at, Time.zone.now) }
      end
    ensure
      writer.close
    end

    def format_application(data, rpo: 0)
      form = EducationForm::Forms::Base.build(data)
      # TODO(molson): Once we have a column in the db with the form type, we can move
      # this tracking code to somewhere more reasonable.
      track_form_type(form.class::TYPE, rpo)
      form
    rescue
      raise FormattingError, "Could not format #{data.confirmation_number}"
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
      ids = records.map { |r| r.record.id }
      logger.info("Writing #{records.count} application(s) to #{filename}")
      logger.info("IDs: #{ids}")
    end

    # Useful for alerting and monitoring the numbers of successfully send submissions
    # per-rpo, rather than the number of records that were *prepared* to be sent.
    def track_submissions(region_id)
      stats[region_id].each do |type, count|
        StatsD.gauge("worker.education_benefits_claim.transmissions.#{region_id}.#{type}", count)
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
