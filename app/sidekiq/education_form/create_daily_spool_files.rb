# frozen_string_literal: true

require 'net/sftp'
require 'sentry_logging'
require 'sftp_writer/factory'

module EducationForm
  class FormattingError < StandardError
  end

  class DailySpoolFileError < StandardError
  end

  class CreateDailySpoolFiles
    MAX_RETRIES = 5
    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"
    STATSD_KEY = 'worker.education_benefits_claim'
    STATSD_FAILURE_METRIC = "#{STATSD_KEY}.failed_spool_file".freeze
    LIVE_FORM_TYPES = %w[1990 1995 1990e 5490 1990n 5495 0993 0994 10203 1990S].map { |t| "22-#{t.upcase}" }.freeze
    AUTOMATED_DECISIONS_STATES = [nil, 'denied', 'processed'].freeze
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options queue: 'default',
                    unique_for: 30.minutes,
                    retry: 5

    # Setting the default value to the `unprocessed` scope is safe
    # because the execution of the query itself is deferred until the
    # data is accessed by the code inside of the method.
    def perform
      retry_count = 0

      begin
        records = EducationBenefitsClaim
                  .unprocessed.joins(:saved_claim).includes(:education_stem_automated_decision).where(
                    saved_claims: {
                      form_id: LIVE_FORM_TYPES
                    },
                    education_stem_automated_decisions: { automated_decision_state: AUTOMATED_DECISIONS_STATES }
                  )
        return false if federal_holiday?

        if records.count.zero?
          log_info('No records to process.')
          return true
        elsif retry_count.zero?
          log_info("Processing #{records.count} application(s)")
        end

        # Group the formatted records into different regions
        regional_data = group_submissions_by_region(records)
        formatted_records = format_records(regional_data)
        # Create a remote file for each region, and write the records into them
        writer = SFTPWriter::Factory.get_writer(Settings.edu.sftp).new(Settings.edu.sftp, logger:)
        write_files(writer, structured_data: formatted_records)
      rescue => e
        StatsD.increment("#{STATSD_FAILURE_METRIC}.general")
        if retry_count < MAX_RETRIES
          log_exception(DailySpoolFileError.new("Error creating spool files.\n\n#{e}
                                                 Retry count: #{retry_count}. Retrying..... "))
          retry_count += 1
          sleep(10 * retry_count) # exponential backoff for retries
          retry
        else
          log_exception(DailySpoolFileError.new("Error creating spool files.
                                                 Job failed after #{MAX_RETRIES} retries \n\n#{e}"))
        end
      end
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
      raw_groups = grouped_data.each do |region, v|
        region_id = EducationFacility.facility_for(region:)
        grouped_data[region] = v.map do |record|
          format_application(record, rpo: region_id)
        end.compact
      end
      # delete any regions that only had malformed claims before returning
      raw_groups.delete_if { |_, v| v.empty? }
    end

    # Write out the combined spool files for each region along with recording
    # and tracking successful transfers.
    # Creates or updates an SpoolFileEvent for tracking and to prevent multiple files per RPO per date during retries
    def write_files(writer, structured_data:)
      structured_data.each do |region, records|
        region_id = EducationFacility.facility_for(region:)
        filename = "#{region_id}_#{Time.zone.now.strftime('%m%d%Y_%H%M%S')}_vetsgov.spl"
        spool_file_event = SpoolFileEvent.build_event(region_id, filename)

        if spool_file_event.successful_at.present?
          log_info("A spool file for #{region_id} on #{Time.zone.now.strftime('%m%d%Y')} was already created")
        else
          log_submissions(records, filename, region)
          # create the single textual spool file
          contents = records.map(&:text).join(EducationForm::CreateDailySpoolFiles::WINDOWS_NOTEPAD_LINEBREAK)

          begin
            log_info("Uploading #{contents.size} bytes to region: #{region}") if Settings.hostname.eql?('api.va.gov')
            bytes_sent = writer.write(contents, filename)

            if bytes_sent.eql?(contents.size) && Settings.hostname.eql?('api.va.gov')
              log_info("Successfully uploaded #{bytes_sent} bytes to region: #{region}")
            elsif Settings.hostname.eql?('api.va.gov')
              log_info("Warning: Uploaded #{bytes_sent} bytes to region: #{region}")
            end

            ## Testing to see if writer is the cause for retry attempt failures
            ## If we get to this message, it's not the writer object
            log_info("Successfully wrote #{records.count} applications to filename: #{filename} for region: #{region}")

            # send copy of staging spool files to testers
            # This mailer is intended to only work for development, staging and NOT production
            # Rails.env will return 'production' on the development & staging servers and  which
            # will trip the unwary. To be safe, use Settings.hostname
            email_staging_spool_files(contents) if local_or_staging_env?

            # track and update the records as processed once the file has been successfully written
            track_submissions(region_id)

            records.each { |r| r.record.update(processed_at: Time.zone.now) }
            spool_file_event.update(number_of_submissions: records.count, successful_at: Time.zone.now)
          rescue => e
            StatsD.increment("#{STATSD_FAILURE_METRIC}.#{region_id}")
            attempt_msg = if spool_file_event.retry_attempt.zero?
                            'initial attempt'
                          else
                            "attempt #{spool_file_event.retry_attempt}"
                          end
            exception = DailySpoolFileError.new("Error creating #{filename} during #{attempt_msg}.\n\n#{e}")
            log_exception(exception, region)
            if spool_file_event.retry_attempt < MAX_RETRIES
              spool_file_event.update(retry_attempt: spool_file_event.retry_attempt + 1)

              # Reinstantiate the writer before retrying
              writer = SFTPWriter::Factory.get_writer(Settings.edu.sftp).new(Settings.edu.sftp, logger:)
              retry
            else
              next
            end
          end
        end
      end
    ensure
      writer.close
    end

    # Previously there was data.saved_claim.valid? check but this was causing issues for forms when
    # 1. on submission the submission data is validated against vets-json-schema
    # 2. vets-json-schema is updated in vets-api
    # 3. during spool file creation the schema is then again validated against vets-json-schema
    # 4. submission is no longer valid due to changes in step 2
    def format_application(data, rpo: 0)
      form = EducationForm::Forms::Base.build(data)
      track_form_type("22-#{data.form_type}", rpo)
      form
    rescue => e
      inform_on_error(data, rpo, e)
      nil
    end

    def inform_on_error(claim, region, error = nil)
      StatsD.increment("#{STATSD_KEY}.failed_formatting.#{region}.22-#{claim.form_type}")
      exception = if error.present?
                    FormattingError.new("Could not format #{claim.confirmation_number}.\n\n#{error}")
                  else
                    FormattingError.new("Could not format #{claim.confirmation_number}")
                  end
      log_exception(exception, nil, send_email: false)
    end

    private

    def federal_holiday?
      holiday = Holidays.on(Time.zone.today, :us, :observed)
      if holiday.empty?
        false
      else
        log_info("Skipping on a Holiday: #{holiday.first[:name]}")
        true
      end
    end

    # Useful for debugging which records were or were not sent over successfully,
    # in case of network failures.
    def log_submissions(records, filename, region)
      log_info("Writing #{records.count} application(s) to #{filename} for region: #{region}")
    end

    # Useful for alerting and monitoring the numbers of successfully send submissions
    # per-rpo, rather than the number of records that were *prepared* to be sent.
    def track_submissions(region_id)
      stats[region_id].each do |type, count|
        StatsD.gauge("#{STATSD_KEY}.transmissions.#{region_id}.#{type}", count)
      end
    end

    def track_form_type(type, rpo)
      stats[rpo][type] += 1
    end

    def stats
      @stats ||= Hash.new(Hash.new(0))
    end

    def log_exception(exception, region = nil, send_email: true)
      log_exception_to_sentry(exception)
      log_to_slack(exception.to_s)
      log_to_email(region) if send_email
    end

    def log_info(message)
      logger.info(message)
      log_to_slack(message)
    end

    def log_to_slack(message)
      return unless Flipper.enabled?(:spool_testing_error_2)

      client = SlackNotify::Client.new(webhook_url: Settings.edu.slack.webhook_url,
                                       channel: '#vsa-education-logs',
                                       username: "#{self.class.name} - #{Settings.vsp_environment}")
      client.notify(message)
    end

    def log_to_email(region)
      return unless Flipper.enabled?(:spool_testing_error_3) && !FeatureFlipper.staging_email?

      CreateDailySpoolFilesMailer.build(region).deliver_now
    end

    def email_staging_spool_files(contents)
      CreateStagingSpoolFilesMailer.build(contents).deliver_now
    end

    def local_or_staging_env?
      Rails.env.eql?('development') || Settings.hostname.eql?('staging-api.va.gov')
    end
  end
end
