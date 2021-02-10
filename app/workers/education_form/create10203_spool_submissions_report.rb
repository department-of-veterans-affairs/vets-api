# frozen_string_literal: true

module EducationForm
  class Create10203SpoolSubmissionsReport
    require 'csv'
    include Sidekiq::Worker

    def format_name(full_name)
      return if full_name.blank?

      [full_name['first'], full_name['last']].compact.join(' ')
    end

    def processed_at_range
      (@time - 24.hours)..@time
    end

    def denied(state)
      denied?(state) ? 'Y' : 'N'
    end

    def denied?(state)
      state == 'denied'
    end

    def poa?(poa)
      return '' if poa.nil?

      poa ? 'Y' : 'N'
    end

    def create_csv_array
      data = {
        csv_array: []
      }
      header_row(data)

      submissions = processed_submissions
      denial_count = 0

      submissions.find_each do |education_benefits_claim|
        automated_decision_state = education_benefits_claim.education_stem_automated_decision&.automated_decision_state
        denial_count += 1 if denied?(automated_decision_state)

        data[:csv_array] << row(education_benefits_claim)
      end

      # Totals row
      data[:csv_array] << ['Total Submissions and Denials', '', '', '', submissions.count, denial_count, '']
      data
    end

    def header_row(data)
      data[:csv_array] << ['Submitted VA.gov Applications - Report YYYY-MM-DD', 'Claimant Name',
                           'Veteran Name', 'Confirmation #', 'Time Submitted', 'Denied (Y/N)',
                           'POA (Y/N)', 'RPO']
      data
    end

    def processed_submissions
      EducationBenefitsClaim.includes(:saved_claim, :education_stem_automated_decision).where(
        processed_at: processed_at_range,
        saved_claims: {
          form_id: '22-10203'
        }
      )
    end

    def row(ebc)
      parsed_form = ebc.parsed_form

      ['',
       format_name(parsed_form['relativeFullName']),
       format_name(parsed_form['veteranFullName']),
       ebc.confirmation_number,
       ebc.processed_at.to_s,
       denied(ebc.education_stem_automated_decision&.automated_decision_state),
       poa?(ebc.education_stem_automated_decision&.poa),
       ebc.regional_processing_office]
    end

    def perform
      return false unless Flipper.enabled?(:stem_automated_decision)

      @time = Time.zone.now
      folder = 'tmp/spool10203_reports'
      FileUtils.mkdir_p(folder)
      filename = "#{folder}/#{@time.to_date}.csv"
      csv_array_data = create_csv_array
      csv_array = csv_array_data[:csv_array]
      CSV.open(filename, 'wb') do |csv|
        csv_array.each do |row|
          csv << row
        end
      end

      return false unless FeatureFlipper.send_edu_report_email?

      Spool10203SubmissionsReportMailer.build(filename).deliver_now
    end
  end
end
