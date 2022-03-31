# frozen_string_literal: true

module RapidReadyForDecision
  class FastTrackPdfGenerator
    PDF_MARKUP_SETTINGS = {
      text: {
        size: 11
      },
      heading4: {
        margin_top: 12
      },
      table: {
        width: 150,
        cell: {
          size: 10,
          border_width: 0,
          background_color: 'f3f3f3'
        }
      }
    }.freeze

    def initialize(patient_info, blood_pressure_data, medications)
      @pdf = Prawn::Document.new
      @patient_info = patient_info
      @blood_pressure_data = blood_pressure_data
      @medications = medications
      @date = Time.zone.today
      @pdf.markup_options = PDF_MARKUP_SETTINGS
    end

    # progressively builds a pdf and is sensitive to sequence
    def generate
      add_intro
      add_blood_pressure_list
      add_blood_pressure_outro
      add_medications_list
      add_about

      @pdf
    end

    private

    def blood_pressure_data?
      @blood_pressure_data.length.positive?
    end

    def medications?
      @medications.any?
    end

    def blood_pressure_start_date
      (@date - 1.year).strftime('%m/%d/%Y')
    end

    def blood_pressure_end_date
      @date.strftime('%m/%d/%Y')
    end

    def add_intro
      patient_info = @patient_info.with_indifferent_access
      full_name = [patient_info[:first], patient_info[:middle], patient_info[:last]].reject(&:blank?).join ' '
      patient_name = [full_name, patient_info[:suffix]].reject(&:blank?).join ', '
      birthdate = patient_info[:birthdate]
      generated_time = Time.now.getlocal
      generated_at = "#{generated_time.strftime('%m/%d/%Y')} at #{generated_time.strftime('%l:%M %p %Z')}"

      intro_lines = [
        "<font size='11'>Hypertension Rapid Ready for Decision | Claim for Increase</font>\n",
        "<font size='22'>VHA Hypertension Data Summary for</font>",
        "<font size='10'><i>Generated automatically on #{generated_at}</i></font>\n",
        "<font size='11'>\n</font>",
        "<font size='14'>#{patient_name}</font>\n",
        birthdate ? "<font size='11'>DOB: #{birthdate}</font>\n" : '',
        "<font size='11'>\n</font>"
      ]

      intro_lines.each do |line|
        @pdf.text line, inline_format: true
      end
    end

    def add_blood_pressure_list
      template = File.read('app/services/rapid_ready_for_decision/views/hypertension/blood_pressure_readings.erb')
      @pdf.markup ERB.new(template).result(binding)
    end

    def add_blood_pressure_outro
      template = File.read('app/services/rapid_ready_for_decision/views/hypertension/rating_schedule.erb')
      @pdf.markup ERB.new(template).result(binding)
    end

    def add_medications_list
      @pdf.text "\n", size: 12

      template = File.read('app/services/rapid_ready_for_decision/views/shared/medications.erb')
      @pdf.markup ERB.new(template).result(binding)
    end

    def add_about
      @pdf.start_new_page

      template = File.read('app/services/rapid_ready_for_decision/views/hypertension/about.erb')
      @pdf.markup ERB.new(template).result(binding)
    end
  end
end
