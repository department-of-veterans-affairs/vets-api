# frozen_string_literal: true

module EducationForm::Forms
  class Base
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require 'erb'

    TEMPLATE_PATH = Rails.root.join('app', 'workers', 'education_form', 'templates')

    attr_accessor :form, :record, :text

    def self.build(app)
      klass = "EducationForm::Forms::VA#{app.form_type}".constantize
      klass.new(app)
    end

    def direct_deposit_type(type)
      dd_types = { 'STARTUPDATE' => 'Start or Update', 'STOP' => 'Stop', 'NOCHANGE' => 'Do Not Change' }
      dd_types[type&.upcase]
    end

    def ssn_gender_dob(veteran = true)
      prefix = veteran ? 'veteran' : 'relative'
      ssn = @applicant.public_send("#{prefix}SocialSecurityNumber")
      gender = @applicant.gender
      dob = @applicant.public_send("#{prefix}DateOfBirth")

      "SSN: #{ssn}         Sex: #{gender}             Date of Birth: #{dob}"
    end

    def benefit_type(application)
      application.benefit&.gsub('chapter', 'CH')
    end

    def disclosure_for(type)
      return if type.blank?

      "#{parse_with_template_path("1990-disclosure/_#{type}")}\n"
    end

    def header_form_type
      "V#{@record.form_type}"
    end

    def school
      @applicant.school
    end

    def applicant_name
      @applicant.veteranFullName
    end

    def applicant_ssn
      @applicant.veteranSocialSecurityNumber
    end

    def initialize(app)
      @record = app
      @form = app.open_struct_form
      @text = format unless instance_of?(Base)
    end

    # @note
    #   The input fixtures in {spec/fixtures/education_benefits_claims/**/*.json contain
    #   Windows-1252 encoding "double right-single-quotation-mark", (’) Unicode %u2019
    #   but .spl file (expected output) contains ASCII apostrophe ('), code %27.
    #
    #   Workaround is to sub the ASCII apostrophe, though other non-UTF-8 chars might break specs
    #
    # Convert the JSON/OStruct document into the text format that we submit to the backend
    def format
      @applicant = @form
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      wrapped = word_wrap(parse_with_template_path(@record.form_type), line_width: 78)
      wrapped = wrapped.gsub(/’|‘/, "'").gsub(/”|“/, '"')
      # We can only send ASCII, so make a best-effort at that.
      transliterated = ActiveSupport::Inflector.transliterate(wrapped, locale: :en)
      # Trim any lines that end in whitespace, but keep the lines themselves
      transliterated.gsub!(/ +\n/, "\n")
      # The spool file must actually use windows style linebreaks
      transliterated.gsub("\n", EducationForm::CreateDailySpoolFiles::WINDOWS_NOTEPAD_LINEBREAK)
    end

    def parse_with_template(template)
      # Because our template files end in newlines, we have to
      # chomp off the final rendered line to get the correct
      # output. Any intentionally blank lines before the final
      # one will remain.
      ERB.new(template, trim_mode: '-').result(binding).chomp
    end

    def parse_with_template_path(path)
      parse_with_template(get_template(path))
    end

    def header
      parse_with_template_path('header')
    end

    def get_template(filename)
      File.read(File.join(TEMPLATE_PATH, "#{filename}.erb"))
    end

    ### Common ERB Helpers

    # N/A is used for "the user wasn't shown this option", which is distinct from Y/N.
    def yesno(bool)
      return 'N/A' if bool.nil?

      bool ? 'YES' : 'NO'
    end

    def yesno_or_blank(bool)
      return '' if bool.nil?

      bool ? 'YES' : 'NO'
    end

    def value_or_na(value)
      value.nil? ? 'N/A' : value
    end

    # is this needed? will it the data come in the correct format? better to have the helper..
    def to_date(date)
      date || (' ' * 10) # '00/00/0000'.length
    end

    def full_name(name)
      return '' if name.nil?

      [name.first, name.middle, name.last, name&.suffix].compact.join(' ')
    end

    def school_name
      school&.name&.upcase&.strip
    end

    def school_name_and_addr(school)
      return '' if school.nil?

      [
        school.name,
        full_address(school.address)
      ].compact.join("\n")
    end

    def full_address(address, indent: false)
      return '' if address.nil?

      seperator = indent ? "\n        " : "\n"
      [
        address.street,
        address.street2,
        [address.city, address.state, address.postalCode].compact.join(', '),
        address.country
      ].compact.join(seperator).upcase
    end

    def full_address_with_street3(address, indent: false)
      return '' if address.nil?

      seperator = indent ? "\n        " : "\n"
      [
        address.street,
        address.street2,
        address.street3,
        [address.city, address.state, address.postalCode].compact.join(', '),
        address.country
      ].compact.join(seperator).upcase
    end

    def hours_and_type(training)
      return_val = training&.hours&.to_s
      return '' if return_val.blank?

      hours_type = training&.hoursType
      return_val += " (#{hours_type})" if hours_type.present?

      return_val
    end

    def employment_history(job_history, post_military: nil)
      wrapped_list = Array(job_history)
      wrapped_list = wrapped_list.select { |job| job.postMilitaryJob == post_military } unless post_military.nil?
      # we need at least one record to be in the form.
      wrapped_list << OpenStruct.new if wrapped_list.empty?
      wrapped_list.map do |job|
        "        Principal Occupation: #{job.name}
        Number of Months: #{job.months}
        License or Rating: #{job.licenseOrRating}"
      end.join("\n\n")
    end
  end
end
