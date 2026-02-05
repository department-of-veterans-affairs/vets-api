# frozen_string_literal: true

require 'net/sftp'
require 'vets/shared_logging'
require 'sftp_writer/factory'

module EducationForm
  class DailyExcelFileError < StandardError
  end

  class CreateDailyExcelFiles
    MAX_RETRIES = 5
    STATSD_KEY = 'worker.education_benefits_claim'
    STATSD_FAILURE_METRIC = "#{STATSD_KEY}.failed_excel_file".freeze
    LIVE_FORM_TYPES = ['22-10282'].freeze
    AUTOMATED_DECISIONS_STATES = [nil, 'denied', 'processed'].freeze
    EXCEL_FIELDS = %w[
      name
      first_name
      last_name
      military_affiliation
      phone_number
      email_address
      country
      state
      race_ethnicity
      gender
      education_level
      employment_status
      salary
      technology_industry
    ].freeze
    HEADERS = ['Name', 'First Name', 'Last Name', 'Select Military Affiliation',
               'Phone Number', 'Email Address', 'Country', 'State', 'Race/Ethnicity',
               'Gender of Applicant', 'What is your highest level of education?',
               'Are you currently employed?', 'What is your current salary?',
               'Are you currently working in the technology industry? (If so, please select one)'].freeze
    include Sidekiq::Job
    include Vets::SharedLogging
    sidekiq_options queue: 'default',
                    unique_for: 30.minutes,
                    retry: 5

    # rubocop:disable Metrics/MethodLength
    def perform
      return unless Flipper.enabled?(:form_10282_sftp_upload)

      retry_count = 0
      filename = "22-10282_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}.csv"
      excel_file_event = ExcelFileEvent.build_event(filename)
      begin
        records = EducationBenefitsClaim
                  .unprocessed
                  .joins(:saved_claim)
                  .where(
                    saved_claims: {
                      form_id: LIVE_FORM_TYPES
                    }
                  )
        return false if federal_holiday?

        if records.count.zero?
          log_info('CreateDailyExcelFiles: No records to process.')
          return true
        elsif retry_count.zero?
          log_info("CreateDailyExcelFiles: Processing #{records.count} application(s)")
        end

        # Format the records and write to CSV file
        formatted_records = format_records(records)
        write_csv_file(formatted_records, filename)

        upload_file_to_sftp(filename)

        # Make records processed and add excel file event for rake job
        records.each { |r| r.update(processed_at: Time.zone.now) }
        excel_file_event.update(number_of_submissions: records.count, successful_at: Time.zone.now)
      rescue => e
        StatsD.increment("#{STATSD_FAILURE_METRIC}.general")
        if retry_count < MAX_RETRIES
          log_exception(DailyExcelFileError.new("Error creating excel files.\n\n#{e}
                                                 Retry count: #{retry_count}. Retrying..... "))
          retry_count += 1
          sleep(10 * retry_count) # exponential backoff for retries
          retry
        else
          log_exception(DailyExcelFileError.new("Error creating excel files.
                                                 Job failed after #{MAX_RETRIES} retries \n\n#{e}"))
        end
      end
      true
    end

    def write_csv_file(records, filename)
      retry_count = 0

      begin
        # Generate CSV string content instead of writing to file
        csv_contents = CSV.generate do |csv|
          # Add headers
          csv << HEADERS

          # Add data rows
          records.each_with_index do |record, index|
            log_info("CreateDailyExcelFiles: Processing record #{index + 1}: #{record.inspect}")

            begin
              row_data = EXCEL_FIELDS.map do |field|
                value = record.public_send(field)
                value.is_a?(Hash) ? value.to_s : value
              end

              csv << row_data
            rescue => e
              log_exception(DailyExcelFileError.new("Failed to add row #{index + 1}:\n"))
              log_exception(DailyExcelFileError.new("#{e.message}\nRecord: #{record.inspect}"))
              next
            end
          end
        end

        # Write to file for backup/audit purposes
        File.write("tmp/#{filename}", csv_contents)
        log_info('CreateDailyExcelFiles: Successfully created CSV file')

        # Return the CSV contents
        csv_contents
      rescue => e
        StatsD.increment("#{STATSD_FAILURE_METRIC}.general")
        log_exception(DailyExcelFileError.new('Error creating CSV files.'))

        if retry_count < MAX_RETRIES
          log_exception(DailyExcelFileError.new("Retry count: #{retry_count}. Retrying..... "))
          retry_count += 1
          sleep(5)
          retry
        else
          log_exception(DailyExcelFileError.new("Job failed after #{MAX_RETRIES} retries \n\n#{e}"))
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    def format_records(records)
      records.map do |record|
        format_application(record)
      end.compact
    end

    def format_application(data)
      form = EducationForm::Forms::Base.build(data)
      track_form_type("22-#{data.form_type}")
      form
    rescue => e
      inform_on_error(data, e)
      nil
    end

    def inform_on_error(claim, error = nil)
      StatsD.increment("#{STATSD_KEY}.failed_formatting.22-#{claim.form_type}")
      exception = if error.present?
                    FormattingError.new("Could not format #{claim.confirmation_number}.\n\n#{error}")
                  else
                    FormattingError.new("Could not format #{claim.confirmation_number}")
                  end
      log_exception(exception)
    end

    private

    def federal_holiday?
      holiday = Holidays.on(Time.zone.today, :us, :observed)
      if holiday.empty?
        false
      else
        log_info("CreateDailyExcelFiles: Skipping on a Holiday: #{holiday.first[:name]}")
        true
      end
    end

    def track_form_type(type)
      StatsD.gauge("#{STATSD_KEY}.transmissions.#{type}", 1)
    end

    def log_exception(exception)
      log_exception_to_sentry(exception)
    end

    def log_info(message)
      logger.info(message)
    end

    def upload_file_to_sftp(filename)
      log_info('Form 10282 SFTP Upload: Begin')

      options = Settings.form_10282.sftp.merge!(allow_staging_uploads: true)

      writer = SFTPWriter::Factory.get_writer(options).new(options, logger:)
      file_size = File.size("tmp/#{filename}")
      bytes_sent = writer.write(File.open("tmp/#{filename}"), filename)
      log_info("Form 10282 SFTP Upload: wrote #{bytes_sent} bytes of a #{file_size} byte file")

      log_info('Form 10282 SFTP Upload: Complete')
    rescue => e
      log_exception(DailyExcelFileError.new("Failed SFTP upload: #{e.message}"))
      raise
    ensure
      writer&.close
    end
  end
end
