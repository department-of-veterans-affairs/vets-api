# frozen_string_literal: true

module FastTrack
  class HypertensionPdfGenerator
    attr_accessor :patient, :bp_data, :medications

    def initialize(patient, bp_data, medications, date)
      @patient = patient
      @bp_data = bp_data
      @medications = medications
      @date = date
    end

    def generate
      pdf = Prawn::Document.new
      pdf = add_intro(pdf)
      pdf = add_blood_pressure(pdf)
      pdf = add_medications(pdf) if medications.length > 1
      add_about(pdf)
    end

    def stringify_patient
      names = patient.with_indifferent_access
      full_name = [names[:first], names[:middle], names[:last]].reject(&:blank?).join ' '
      [full_name, names[:suffix]].reject(&:blank?).join ', '
    end

    def add_intro(pdf)
      patient_name = stringify_patient
      generated_time = Time.now.getlocal
      generated_at = "#{generated_time.strftime('%m/%d/%Y')} at #{generated_time.strftime('%l:%M %p %Z')}"

      intro_lines = [
        "<font size='11'>Hypertension Rapid Ready for Decision | Claim for Increase</font>\n",
        "<font size='22'>VHA Hypertension Data Summary for</font>",
        "<font size='22'>#{patient_name}</font>\n",
        "<font size='10'><i>Generated automatically on #{generated_at}<i>\n"
      ]

      intro_lines.each do |line|
        pdf.text line, inline_format: true
      end

      pdf.text "\n", size: 10

      pdf
    end

    def add_blood_pressure(pdf)
      with_intro = add_blood_pressure_intro(pdf)
      with_bp = add_blood_pressure_list(with_intro)
      with_bp.text "\n", size: 12
      add_blood_pressure_outro(with_bp)
    end

    def add_blood_pressure_intro(pdf)
      header = bp_data.length.positive? ? 'One Year of Blood Pressure History' : 'No blood pressure records found'
      bp_note =
        bp_data.length.positive? ? "<font size='11'>Blood pressure is shown as systolic/diastolic.\n</font>" : ''
      end_date = @date.strftime('%m/%d/%Y')
      start_date = (@date - 1.year).strftime('%m/%d/%Y')
      search_window = "VHA records searched from #{start_date} to #{end_date}"
      bp_intro_lines = [
        "<font size='16'>#{header}</font>",
        "<font size='11'><i>#{search_window}<i></font>",
        "<font size='11'><i>All VAMC locations using VistA/CAPRI were checked<i></font>",
        "\n",
        bp_note
      ]

      bp_intro_lines.each do |line|
        pdf.text line, inline_format: true
      end

      return pdf unless bp_data.length.positive?

      pdf.text "\n", size: 10

      pdf
    end

    def add_blood_pressure_list(pdf)
      @bp_data.each do |bp|
        pdf.text "<b>Blood pressure: #{bp[:systolic]['value']}/#{bp[:diastolic]['value']} #{bp[:systolic]['unit']}",
                 inline_format: true, size: 11
        pdf.text "Taken on: #{bp[:issued][0, 10].to_date.strftime('%m/%d/%Y')}", size: 11
        pdf.text "Location: #{bp[:organization] || 'Unknown'}", size: 11
        pdf.text "\n", size: 8
      end

      pdf.text "\n", size: 12

      pdf
    end

    def add_blood_pressure_table(pdf)
      # The table version of the medications, which we may need for future user
      # testing.
      bp_rows = [['<b>Blood pressure</b>', '<b>Date</b>', '<b>Location</b>']]
      @bp_data.each do |bp|
        bp_rows.append([
                         "#{bp[:systolic]['value']}/#{bp[:diastolic]['value']} #{bp[:systolic]['unit']}",
                         bp[:issued][0, 10].to_date.strftime('%m/%d/%Y'),
                         bp[:organization] || 'Unknown'
                       ])
      end
      pdf.table(bp_rows, cell_style: { size: 8, inline_format: true })

      pdf
    end

    def rating_schedule
      [
        [
          '10%',
          'Systolic pressure predominantly 160 or more; or diastolic pressure predominantly 100 or more; ' \
          'or minimum evaluation for an individual with a history of diastolic pressure predominantly' \
          '100 or more who requires continuous medication for control'
        ],
        [
          '20%',
          'Systolic pressure predominantly 200 or more; ' \
          'or diastolic pressure predominantly 110 or more'
        ],
        [
          '40%', 'Diastolic pressure 120 or more'
        ],
        [
          '60%', 'Diastolic pressure 130 or more'
        ]
      ].freeze
    end

    def rating_schedule_link
      "<link href='" \
        'https://www.ecfr.gov/current/title-38/' \
        "chapter-I/part-4'>View rating schedule</link>"
    end

    def add_blood_pressure_outro(pdf)
      pdf.text 'Hypertension Rating Schedule', size: 14
      pdf.table(
        rating_schedule, width: 350, column_widths: [30, 320], cell_style: {
          size: 10, border_width: 0, background_color: 'f3f3f3'
        }
      )

      pdf.text "\n"
      pdf.text rating_schedule_link,
               inline_format: true, color: '0000ff', size: 11
      pdf
    end

    def add_medications(pdf)
      pdf = add_medications_intro(pdf)
      add_medications_list(pdf)
    end

    def add_medications_intro(pdf)
      pdf.text "\n", size: 11
      pdf.text 'Active Prescriptions', size: 16

      med_search_window = 'VHA records searched for medication prescriptions active as of ' \
                          "#{Time.zone.today.strftime('%m/%d/%Y')}"
      prescription_lines = [
        med_search_window,
        'All VAMC locations using VistA/CAPRI were checked',
        "\n"
      ]

      prescription_lines.each do |line|
        pdf.text line, size: 11, style: :italic
      end

      pdf
    end

    def add_medications_list(pdf)
      @medications.each do |medication|
        pdf.text medication['description'], size: 11, style: :bold
        pdf.text "Prescribed on: #{medication['authoredOn'][0, 10].to_date.strftime('%m/%d/%Y')}"
        if medication['dosageInstructions'].present?
          pdf.text "Dosage instructions: #{medication['dosageInstructions'].join('; ')}"
        end
        pdf.text "\n", size: 8
      end

      pdf
    end

    def add_medications_table(pdf)
      # The table version of the medications, which we may need for future user
      # testing.
      med_rows = [[
        '<b>Medication</b>',
        '<b>Prescribed on</b>',
        '<b>Dosage instructions</b>'
      ]]

      @medications.each do |medication|
        issued_date = medication['authoredOn'][0, 10].to_date.strftime('%m/%d/%Y')
        instructions = medication['dosageInstructions'].join('; ')
        med_rows.append([medication['description'], issued_date, instructions])
      end

      pdf.table(med_rows, cell_style: { size: 8, inline_format: true })

      pdf
    end

    def about_lines
      ['The Hypertension Rapid Ready for Decision system retrieves and summarizes ' \
       'VHA medical records related to hypertension claims for increase submitted on va.gov. ' \
       'VSRs and RVSRs can develop and rate this claim without ordering an exam if there is '\
       'sufficient existing evidence to show predominance according to ' \
       '<link href="https://www.ecfr.gov/current/title-38/part-4">' \
       '<color rgb="0000ff">DC 7101 (Hypertension) Rating Criteria</color></link>. ' \
       'This is not new guidance, but rather a way to ' \
       '<link href="https://www.ecfr.gov/current/title-38/chapter-I/part-3/' \
       'subpart-A/subject-group-ECFR7629a1b1e9bf6f8/section-3.159"><color rgb="0000ff">' \
       'operationalize existing statutory rules</color><link> in 38 U.S.C § 5103a(d).',
       "\n",
       'Not included in this document:',
       ' •  Private medical records',
       ' •  VAMC data for clinics using CERNER Electronic Health Record system ' \
       '(Replacing VistA, but currently only used at Mann-Grandstaff VA Medical Center in Spokane, Washington)',
       ' •  JLV/Department of Defense medical records'].freeze
    end

    def add_about(pdf)
      pdf.text  "\n"
      pdf.text  'About this Document', size: 14
      about_lines.each do |line|
        pdf.text line, size: 11, inline_format: true
      end

      pdf
    end
  end
end
