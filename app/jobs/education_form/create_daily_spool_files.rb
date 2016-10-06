# frozen_string_literal: true
require 'net/sftp'

module EducationForm
  class CreateDailySpoolFiles < ActiveJob::Base
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require 'erb'
    require 'ostruct'

    queue_as :default

    TEMPLATE = File.read(Rails.root.join('app', 'jobs', 'education_form', 'templates', '22-1990.erb'))

    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"

    # TODO: make sure we rescue from all possible SFTP exceptions
    rescue_from(Net::ReadTimeout) do
      retry_job(wait: 1.minute)
    end

    def perform
      # Fetch all the records for the day
      records = EducationBenefitsClaim.unprocessed
      # Group the formatted records into different regions
      regional_data = group_submissions_by_region(records)
      # Create a remote file for each region, and write the records into them
      create_files(regional_data)
      # mark the records as processed
      records.update_all(processed_at: Time.zone.now)
      # TODO: Log the success/failure of the submission somewhere
      true
    end

    def group_submissions_by_region(records)
      regional_data = Hash.new { |h, k| h[k] = [] }
      records.each do |record|
        form = record.open_struct_form
        region_key = EducationFacility.region_for(form)
        regional_data[region_key] << form
      end
      regional_data
    end

    def write_files(sftp: nil, structured_data:)
      structured_data.each do |region, records|
        filename = "#{Time.zone.today.strftime('%F')}-#{region}.spl"
        file_class =
          if sftp.nil?
            dir_name = 'tmp/spool_files'
            FileUtils.mkdir_p(dir_name)

            filename = "#{dir_name}/#{filename}"

            File
          else
            sftp.file
          end

        Rails.logger.tagged('EDUForm') { |l| l.info("Writing #{records.count} application(s) to #{filename}") }
        f = file_class.open(filename, 'w')
        contents = records.map do |record|
          format_application(record)
        end.join(WINDOWS_NOTEPAD_LINEBREAK)

        f.write(contents)
        f.close
      end
    end

    def create_files(structured_data)
      if Rails.env.development?
        write_files(structured_data: structured_data)
      else
        # TODO: Will be implemented in a follow-up PR.
        Net::SFTP.start(ENV['EDU_SFTP_HOST'], ENV['EDU_SFTP_USER'], password: ENV['EDU_SFTP_PASS']) do |sftp|
          write_files(sftp: sftp, structured_data: structured_data)
        end
      end
    end

    # Convert the JSON document into the text format that we submit to the backend
    def format_application(form)
      @application_template ||= ERB.new(TEMPLATE, nil, '-')
      @applicant = form
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      wrapped = word_wrap(@application_template.result(binding), line_width: 78)
      # The spool file must actually use windows style linebreaks
      wrapped.gsub("\n", WINDOWS_NOTEPAD_LINEBREAK)
    end

    private

    # Used in the INIT header of the 22-1990 template.
    def form_type(application)
      {
        CH33:       'CH33',
        CH33_30:    'CH33',
        CH33_1606:  'CH33',
        CH33_1607:  'CH33',
        CH1606:     'CH1606',
        CH30:       'CH30',
        CH32:       'CH32',
        NA:         'NA'
      }[application.form.to_sym]
    end

    # Some descriptive text that's included near the top of the 22-1990 form
    def disclosure(application)
      contents = File.read(Rails.root.join('app', 'jobs', 'education_form', 'templates', "_#{application.form}.erb"))
      ERB.new(contents).result(binding)
    end

    def full_name(name)
      return '' if name.nil?
      [name.first, name.middle, name.last].compact.join(' ')
    end

    def full_address(address)
      return '' if address.nil?

      [
        address.street,
        address.street2,
        "#{address.city}, #{address.state}, #{address.postalCode}",
        address.country
      ].compact.join("\n").upcase
    end

    def rotc_scholarship_amounts(scholarships)
      # there are 5 years, all of which can be blank.
      # Wrap the array to a size of 5 to meet this requirement
      wrapped_list = Array(scholarships)
      Array.new(5) do |idx|
        "            Year #{idx + 1}:          Amount: #{wrapped_list[idx]&.amount}\n"
      end.join("\n")
    end

    def employment_history(job_history, post_military)
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
  end
end
