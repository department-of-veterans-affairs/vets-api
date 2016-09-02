# frozen_string_literal: true
module EducationForm
  class CreateDailySpoolFiles
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require "erb"
    require "ostruct" # Until this is backed by a model

    TEMPLATE = File.read(Rails.root.join("app", "jobs", "education_form", "templates", "22-1990.erb"))

    WINDOWS_NOTEPAD_LINEBREAK = "\r\n".freeze

    def run(day = Date.yesterday)
      # TODO: get the mapping of schools/regions -> spool file

      dev_spool_output = EducationBenefitsClaim.unprocessed_for(day).each do |data|
      # dev_spool_output = DEVELOPMENT_DATA.map do |data|
        format_application(data)
      end.join(WINDOWS_NOTEPAD_LINEBREAK)
      # File.open(File.expand_path("~/Desktop/sample.win.spl"), 'w') do |f|
      Tempfile.create("education_spoolfile") do |f|
        f.write dev_spool_output
      end

      # if you want to roughly(ish) see what the generated image looks like, output the file to a
      # non-temporary file and run
      # convert -pointsize 10 -density 200 -depth 8 -font Courier text:sample.win.spl sample.win.tiff

      # TODO: SFTP the generated file(s)
      # TODO: Mark the applications as processed once the send is successful
      # TODO: Log the success/failure of the submission somewhere
      # puts formatted_output
      true
    end

    def format_application(application)
      # TODO: Do we need to have different templates for different forms varients?
      @application_template ||= ERB.new(TEMPLATE, nil, "-")
      # OpenStruct is for accessor convenience.
      # ... it's piped through JSON so we can do a deep-struct, OpenStruct.new is shallow
      @applicant = application.open_struct_form
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      wrapped = word_wrap(@application_template.result(binding), line_width: 78)
      # The spool file must actually use windows style linebreaks
      wrapped.gsub("\n", WINDOWS_NOTEPAD_LINEBREAK)
    end

    # Used in the INIT header
    def form_type(application)
      {
        CH33_30:    "CH33",
        CH33_1606:  "CH33",
        CH33_1607:  "CH33",
        CH1606:     "CH1606",
        CH30:       "CH30",
        CH32:       "CH32"
      }[application.form.to_sym]
    end

    def disclosure(application)
      contents = File.read(Rails.root.join("app", "jobs", "education_form", "templates", "_#{application.form}.erb"))
      ERB.new(contents).result(binding)
    end

    # with the binding, we can access helper methods as well
    def full_name(name)
      return "" if name.nil?
      [name.first, name.middle, name.last].compact.join(" ")
    end

    def full_address(address)
      return "" if address.nil?
      if address.country == "USA"
        "#{address.street}\n        #{address.city}, #{address.state}, #{address.zipcode}".upcase
      end
    end

    def rotc_scholarship_amounts(scholarships)
      # there are 5 years, all of which can be blank.
      wrapped_list = Array(scholarships)
      5.times.map do |idx|
        "            Year #{idx + 1}:          Amount: #{wrapped_list[idx]&.amount}\n"
      end.join("\n")
    end

    def employment_history(job_history, post_military)
      wrapped_list = Array(job_history).select { |job| job.postMilitaryJob == post_military }
      # we need at least one record to be in the form.
      wrapped_list << OpenStruct.new if wrapped_list.empty?
      wrapped_list.map do |job|
          "        Principal Occupation: #{job.name}\n        Number of Months: #{job.months}\n        License or Rating: #{job.licenseOrRating}"
      end.join("\n\n")
    end

    def yesno(bool)
      return "N/A" if bool.nil? # TODO: Remove 'N/A' once the form is complete. Used for testing.
      bool ? "YES" : "NO"
    end

    # is this needed? will it the data come in the correct format? better to have the helper..
    def to_date(date)
      date ? date : (" " * 10) # '00/00/0000'
    end

    def self.run(day = Date.yesterday)
      new.run(day)
    end
  end
end
