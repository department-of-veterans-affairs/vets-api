# frozen_string_literal: true
require 'net/sftp'
require 'iconv'

module EducationForm
  class CreateDailySpoolFiles
    include Sidekiq::Worker
    sidekiq_options queue: 'default',
                    retry: 5

    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require 'erb'
    require 'ostruct'

    TEMPLATE_PATH = Rails.root.join('app', 'workers', 'education_form', 'templates')
    TEMPLATE = File.read(File.join(TEMPLATE_PATH, '22-1990.erb'))

    CH33_TYPES = {
      'chapter1607' => 'CH33_1607', 'chapter1606' => 'CH33_1606', 'chapter30' => 'CH33_30'
    }.freeze

    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"

    def perform
      # Fetch all the records for the day
      records = EducationBenefitsClaim.unprocessed
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
      @application_template ||= ERB.new(TEMPLATE, nil, '-')
      @applicant = form
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      wrapped = word_wrap(@application_template.result(binding), line_width: 78)
      # We can only send ASCII, so make a best-effort at that.
      transliterated = Iconv.iconv('ascii//translit', 'utf-8', wrapped).first
      # The spool file must actually use windows style linebreaks
      transliterated.gsub("\n", WINDOWS_NOTEPAD_LINEBREAK)
    end

    private

    def log_submissions(records, filename, region_id)
      logger.info("Writing #{records.count} application(s) to #{filename}")
      logger.info("IDs: #{records.map(&:id)}")
      StatsD.gauge('worker.education_benefits_claim.transmissions', records.count, tags:
        { form: '22-1990', rpo: region_id })
    end

    # If multiple benefit types are selected, we've been told to just include whichever
    # one is 'first' in the header.
    def form_type(application)
      return 'CH1606' if application.chapter1606
      return 'CH33' if application.chapter33
      return 'CH30' if application.chapter30
      return 'CH32' if application.chapter32
    end

    # Some descriptive text that's included near the top of the 22-1990 form. Because they can make
    # multiple selections, we have to add all the selected ones.
    def disclosures(application)
      disclosure_texts = []
      disclosure_texts << disclosure_for('CH30') if application.chapter30
      disclosure_texts << disclosure_for('CH1606') if application.chapter1606
      disclosure_texts << disclosure_for('CH32') if application.chapter32
      if application.chapter33
        ch33_type = CH33_TYPES.fetch(application.benefitsRelinquished, 'CH33')
        disclosure_texts << disclosure_for(ch33_type)
      end
      disclosure_texts.join("\n#{'*' * 78}\n\n")
    end

    def full_name(name)
      return '' if name.nil?
      [name.first, name.middle, name.last].compact.join(' ')
    end

    def full_address(address, indent: false)
      return '' if address.nil?
      seperator = indent ? "\n        " : "\n"
      [
        address.street,
        address.street2,
        "#{address.city}, #{address.state}, #{address.postalCode}",
        address.country
      ].compact.join(seperator).upcase
    end

    def rotc_scholarship_amounts(scholarships)
      # there are 5 years, all of which can be blank.
      # Wrap the array to a size of 5 to meet this requirement
      wrapped_list = Array(scholarships)
      Array.new(5) do |idx|
        "            Year #{idx + 1}:          Amount: #{wrapped_list[idx]&.amount}\n"
      end.join("\n")
    end

    def employment_history(job_history, post_military:)
      wrapped_list = Array(job_history).select { |job| job.postMilitaryJob == post_military }
      # we need at least one record to be in the form.
      wrapped_list << OpenStruct.new if wrapped_list.empty?
      wrapped_list.map do |job|
        "        Principal Occupation: #{job.name}
        Number of Months: #{job.months}
        License or Rating: #{job.licenseOrRating}"
      end.join("\n\n")
    end

    # N/A is used for "the user wasn't shown this option", which is distinct from Y/N.
    def yesno(bool)
      return 'N/A' if bool.nil?
      bool ? 'YES' : 'NO'
    end

    # is this needed? will it the data come in the correct format? better to have the helper..
    def to_date(date)
      date ? date : (' ' * 10) # '00/00/0000'.length
    end

    def disclosure_for(type)
      contents = File.read(File.join(TEMPLATE_PATH, "_#{type}.erb"))
      ERB.new(contents).result(binding)
    end
  end
end
