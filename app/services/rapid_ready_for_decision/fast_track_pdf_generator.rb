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
      add_blood_pressure_intro
      add_blood_pressure_list
      add_blood_pressure_outro
      add_medications_intro
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

    def add_blood_pressure_intro
      header = blood_pressure_data? ? 'One Year of Blood Pressure History' : 'No blood pressure records found'
      bp_note =
        blood_pressure_data? ? "<font size='11'>Blood pressure is shown as systolic/diastolic.\n</font>" : ''
      end_date = @date.strftime('%m/%d/%Y')
      start_date = (@date - 1.year).strftime('%m/%d/%Y')
      search_window = "VHA records searched from #{start_date} to #{end_date}"
      bp_intro_lines = [
        "<font size='16'>#{header}</font>",
        "<font size='11'><i>#{search_window}</i></font>",
        "<font size='11'><i>All VAMC locations using VistA/CAPRI were checked</i></font>",
        "\n",
        bp_note
      ]

      bp_intro_lines.each do |line|
        @pdf.text line, inline_format: true
      end

      return @pdf unless blood_pressure_data?

      @pdf.text "\n", size: 10
    end

    def add_blood_pressure_list
      @blood_pressure_data.each do |bp|
        systolic = bp[:systolic]['value'].round
        diastolic = bp[:diastolic]['value'].round

        @pdf.text "<b>Blood pressure: #{systolic}/#{diastolic}</b>",
                  inline_format: true, size: 11
        @pdf.text "Taken on: #{bp[:effectiveDateTime].to_date.strftime('%m/%d/%Y')} " \
                  "at #{Time.iso8601(bp[:effectiveDateTime]).strftime('%H:%M %Z')}",
                  size: 11
        @pdf.text "Location: #{bp[:organization] || 'Unknown'}", size: 11
        @pdf.text "\n", size: 8
      end

      @pdf.text "\n", size: 12
    end

    def add_blood_pressure_outro
      template = File.read('app/services/rapid_ready_for_decision/views/hypertension/rating_schedule.erb')
      @pdf.markup ERB.new(template).result(binding)
    end

    def add_medications_intro
      @pdf.text "\n", size: 11
      @pdf.text 'Active Prescriptions', size: 16

      return @pdf unless medications?

      med_search_window = 'VHA records searched for medication prescriptions active as of ' \
                          "#{Time.zone.today.strftime('%m/%d/%Y')}"
      prescription_lines = [
        med_search_window,
        'All VAMC locations using VistA/CAPRI were checked',
        "\n"
      ]

      prescription_lines.each do |line|
        @pdf.text line, size: 11, style: :italic
      end
    end

    def add_medications_list
      unless medications?
        @pdf.text 'No active medications were found in the last year', size: 8

        return
      end

      @medications.each do |medication|
        @pdf.text medication['description'], size: 11, style: :bold
        @pdf.text "Prescribed on: #{medication['authoredOn'][0, 10].to_date.strftime('%m/%d/%Y')}"
        if medication['dosageInstructions'].present?
          @pdf.text "Dosage instructions: #{medication['dosageInstructions'].join('; ')}"
        end
        @pdf.text "\n", size: 8
      end
    end

    def add_about
      @pdf.start_new_page

      template = File.read('app/services/rapid_ready_for_decision/views/hypertension/about.erb')
      @pdf.markup ERB.new(template).result(binding)
    end
  end
end
