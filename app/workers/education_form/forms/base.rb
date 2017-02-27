require './app/workers/education_form/create_daily_spool_files'

# frozen_string_literal: true
module EducationForm::Forms
  class Base
    include ActionView::Helpers::TextHelper # Needed for word_wrap
    require 'erb'

    TEMPLATE_PATH = Rails.root.join('app', 'workers', 'education_form', 'templates')

    attr_accessor :form, :record, :text

    def self.build(app)
      klass = app.is_1990? ? VA1990 : VA1995
      klass.new(app)
    end

    def initialize(app)
      @record = app
      @form = app.open_struct_form
      @text = format unless self.class == Base
    end

    # Convert the JSON/OStruct document into the text format that we submit to the backend
    def format
      @applicant = @form
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      wrapped = word_wrap(parse_with_template_path(@record.form_type), line_width: 78)
      # We can only send ASCII, so make a best-effort at that.
      transliterated = Iconv.iconv('ascii//translit', 'utf-8', wrapped).first
      # The spool file must actually use windows style linebreaks
      transliterated.gsub("\n", EducationForm::WINDOWS_NOTEPAD_LINEBREAK)
    end

    def parse_with_template(template)
      # Because our template files end in newlines, we have to
      # chomp off the final rendered line to get the correct
      # output. Any intentionally blank lines before the final
      # one will remain.
      ERB.new(template, nil, '-').result(binding).chomp
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

    def value_or_na(value)
      value.nil? ? 'N/A' : value
    end

    # is this needed? will it the data come in the correct format? better to have the helper..
    def to_date(date)
      date ? date : (' ' * 10) # '00/00/0000'.length
    end

    def full_name(name)
      return '' if name.nil?
      [name.first, name.middle, name.last, name&.suffix].compact.join(' ')
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
        "#{address.city}, #{address.state}, #{address.postalCode}",
        address.country
      ].compact.join(seperator).upcase
    end
  end
end
