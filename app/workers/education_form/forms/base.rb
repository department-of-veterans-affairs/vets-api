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
      template ||= ERB.new(self.class::TEMPLATE, nil, '-')
      @applicant = @form
      # the spool file has a requirement that lines be 80 bytes (not characters), and since they
      # use windows-style newlines, that leaves us with a width of 78
      wrapped = word_wrap(template.result(binding), line_width: 78)
      # We can only send ASCII, so make a best-effort at that.
      transliterated = Iconv.iconv('ascii//translit', 'utf-8', wrapped).first
      # The spool file must actually use windows style linebreaks
      transliterated.gsub("\n", EducationForm::WINDOWS_NOTEPAD_LINEBREAK)
    end

    ### Common ERB Helpers

    # N/A is used for "the user wasn't shown this option", which is distinct from Y/N.
    def yesno(bool)
      return 'N/A' if bool.nil?
      bool ? 'YES' : 'NO'
    end

    # is this needed? will it the data come in the correct format? better to have the helper..
    def to_date(date)
      date ? date : (' ' * 10) # '00/00/0000'.length
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
  end
end
