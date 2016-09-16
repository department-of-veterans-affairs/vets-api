# frozen_string_literal: true
require 'net/sftp'

module EducationForm
  class CreateDailySpoolFiles
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require 'erb'
    require 'ostruct'

    TEMPLATE = File.read(Rails.root.join('app', 'jobs', 'education_form', 'templates', '22-1990.erb'))

    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"

    attr_accessor :files

    def run(day = Date.yesterday)
      # Fetch all the records for the day
      records = EducationBenefitsClaim.unprocessed_for(day)
      # Group the formatted records into different regions
      regional_data = group_submissions(records)
      # Create a remote file for each region, and write the records into them
      create_files(day, regional_data)
      # mark the records as processed
      records.each { |r| r.update(processed_at: Time.zone.utc) }
      # TODO: Log the success/failure of the submission somewhere
      true
    end

    def group_submissions(records)
      regional_data = {}
      records.each do |record|
        form = record.open_struct_form
        region_key = EducationFacility.region_for(form)
        regional_data[region_key] ||= []
        regional_data[region_key] << form
      end
      regional_data
    end

    def create_files(day, structured_data)
      # TODO: Will be implemented in a follow-up PR.
      Net::SFTP.start('host', 'username', password: 'password') do |sftp|
        structured_data.each_with_object({}) do |(region, records), _localfiles|
          remote_name = "#{day.strftime('%F')}-#{region}.spl"
          f = sftp.file.open(remote_name, 'w')
          contents = records.map do |record|
            format_application(record)
          end.join(WINDOWS_NOTEPAD_LINEBREAK)

          f.write(contents)
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

    def self.run(day = Date.yesterday)
      new.run(day)
    end

    private

    # Used in the INIT header of the 22-1990 template.
    def form_type(application)
      {
        CH33_30:    'CH33',
        CH33_1606:  'CH33',
        CH33_1607:  'CH33',
        CH1606:     'CH1606',
        CH30:       'CH30',
        CH32:       'CH32'
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
      if address.country == 'USA'
        "#{address.street}
        #{address.city}, #{address.state}, #{address.zipcode}".upcase
      end
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
