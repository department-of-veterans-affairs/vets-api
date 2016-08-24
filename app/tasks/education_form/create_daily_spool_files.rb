# frozen_string_literal: true
module EducationForm
  class CreateDailySpoolFiles
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require "erb"
    require "ostruct" # Until this is backed by a model

    TEMPLATE = File.read(Rails.root.join("app", "tasks", "education_form", "templates", "22-1990.erb"))

    DEVELOPMENT_DATA = [ # Until this is backed by a model
      {
        first_name: "Mark",
        last_name: "Olson",
        previously_applied_self: true,
        high_school_diploma_date: "05/15/2006",
        sex: "Male",
        birthday: "03/07/1985"
      },
      {
        first_name: "Jane",
        middle_initial: "T",
        last_name: "Doe",
        previously_applied_self: false,
        high_school_diploma_date: nil,
        sex: "Female",
        attaching_dd_214: false,
        recieved_pamphlet: true,
        birthday: "05/01/1984"
      }
    ].freeze

    WINDOWS_NOTEPAD_LINEBREAK = "\r\n".freeze

    def run(_day = Date.yesterday)
      # TODO: get the mapping of schools/regions -> spool file

      # EducationApplication.unprocessed_for(day).each {|data| ...
      dev_spool_output = DEVELOPMENT_DATA.map do |data|
        format_application(data)
      end.join("\n")

      formatted_output = dev_spool_output.gsub("\n", WINDOWS_NOTEPAD_LINEBREAK)
      Tempfile.create("education_spoolfile") do |f|
        f.write formatted_output
      end

      # if you want to roughly(ish) see what the generated image looks like, output the file to a
      # non-temporary file and run
      # convert -pointsize 10 -density 200 -depth 8 -font Courier text:sample.win.spl sample.win.tiff

      # TODO: SFTP the generated file(s)
      # TODO: Mark the applications as processed once the send is successful
      # TODO: Log the success/failure of the submission somewhere
      true
    end

    def format_application(application)
      # TODO: Do we need to have different templates for different forms varients?
      @application_template ||= ERB.new(TEMPLATE)
      # TODO: once the model is in place, just use that. OpenStruct is for accessor convenience
      @applicant = OpenStruct.new(application)
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      word_wrap(@application_template.result(binding), line_width: 78)
    end

    # with the binding, we can access helper methods as well
    def full_name
      [@applicant.first_name, @applicant.middle_initial, @applicant.last_name].compact.join(" ")
    end

    def yesno(bool)
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
