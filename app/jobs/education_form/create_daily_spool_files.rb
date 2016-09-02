# frozen_string_literal: true
module EducationForm
  class CreateDailySpoolFiles
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require "erb"
    require "ostruct" # Until this is backed by a model

    TEMPLATE = File.read(Rails.root.join("app", "jobs", "education_form", "templates", "22-1990.erb"))

    DEVELOPMENT_DATA = [ # Until this is backed by a model
      {
      chapter1606: true,
      form: 'CH33_1607',
      fullName: {
        first: "Mark",
        last: "Olson"
      },
      gender: "M",
      birthday: "03/07/1985",
      socialSecurityNumber: "111223333",
      address: {
        country: "USA",
        state: "WI",
        zipcode: "53130",
        street: "123 Main St",
        city: "Milwaukee"
      },
      phone: "5551110000",
      emergencyContact: {
        fullName: {
          first: "Sibling",
          last: "Olson"
        },
        sameAddressAndPhone: true
      },
      bankAccount: {
        accountType: "checking",
        bankName: "First Bank of JSON",
        routingNumber: "123456789",
        accountNumber: "88888888888"
      },
      previouslyFiledClaimWithVa: false,
      previouslyAppliedWithSomeoneElsesService: false,
      alreadyReceivedInformationPamphlet: true,
      schoolName: "FakeData University",
      schoolAddress: {
        country: "USA",
        state: "MD",
        zipcode: "21231",
        street: "111 Uni Drive",
        city: "Baltimore"
      },
      educationStartDate: "08/29/2016",
      educationalObjective: "...",
      courseOfStudy: "History",
      educationType: {
        college: true,
        testReimbursement: true
      },
      currentlyActiveDuty: false,
      terminalLeaveBeforeDischarge: false,
      highSchoolOrGedCompletionDate: "06/06/2010",
      nonVaAssistance: false,
      guardsmenReservistsAssistance: false,

      additionalContributions: false,
      activeDutyKicker: false,
      reserveKicker: false,
      serviceBefore1977: false,
      # rubocop:disable LineLength
      remarks: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin sit amet ullamcorper est, in interdum velit. Cras purus orci, varius eget efficitur nec, dapibus id risus. Donec in pellentesque enim. Proin sagittis, elit nec consequat malesuada, nibh justo luctus enim, ac aliquet lorem orci vel neque. Ut eget accumsan ipsum. Cras sed venenatis massa. Duis odio urna, laoreet quis ante sed, facilisis congue purus. Etiam semper facilisis luctus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Etiam blandit eget nibh at ornare. Sed non porttitor dui. Proin ornare magna diam, ut lacinia magna accumsan euismod.

      Phasellus et nisl id lorem feugiat molestie. Aliquam molestie,
      nulla eu fringilla finibus, massa lectus varius quam, quis ornare
      sem lorem lacinia dui. Integer consequat non arcu convallis mollis.
      Vivamus magna turpis, pharetra non eros at, feugiat rutrum nisl.
      Maecenas eros tellus, blandit id libero sed, imperdiet fringilla
      eros. Nulla vel tortor vel neque fermentum laoreet id vitae ex.
      Mauris posuere lorem tellus. Pellentesque at augue arcu.
      Vestibulum aliquam urna ac est lacinia, eu congue nisi tempor.
      ",
      # rubocop:enable LineLength
      toursOfDuty: [
        {
          dateRange: {
            from: "01/01/2001",
            to: "10/10/2010"
          },
          serviceBranch: "Army",
          serviceStatus: "Active Duty",
          involuntarilyCalledToDuty: false
        },
        {
          dateRange: {
            from: "01/01/1995",
            to: "10/10/1998"
          },
          serviceBranch: "Army",
          serviceStatus: "Honorable Discharge",
          involuntarilyCalledToDuty: true
        }
      ]
    },
      {
        form: "CH33_30",
        fullName: {
          first: "Jane",
          last: "Doe",
          middle: "T"
        },
        schoolName: "CamelCase SchoolName",
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
      end.join(WINDOWS_NOTEPAD_LINEBREAK)
      File.open(File.expand_path("~/Desktop/sample.win.spl"), 'w') do |f|
      # Tempfile.create("education_spoolfile") do |f|
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
      # TODO: once the model is in place, just use that. OpenStruct is for accessor convenience.
      # ... it's piped through JSON so we can do a deep-struct, OpenStruct.new is shallow
      @applicant = JSON.parse(application.to_json, object_class: OpenStruct)
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
