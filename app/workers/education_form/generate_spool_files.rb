# frozen_string_literal: true

module EducationForm
  class GenerateSpoolFiles
    SPOOL_DATE = '2017-10-26'.to_date
    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"

    def delete_malformed_claims
      malformed = malformed_claim_ids

      edu_claims = malformed[:education_benefits_claims]
      saved_claims = malformed[:saved_claims]
      edu_submissions = malformed[:education_benefits_submissions]
      confirmation_numbers = malformed[:confirmation_numbers]

      filename = write_confirmation_numbers(confirmation_numbers)

      count = 0
      count += EducationBenefitsSubmission.delete(edu_submissions)
      count += EducationBenefitsClaim.delete(edu_claims)
      count += SavedClaim.delete(saved_claims)

      { count: count, filename: filename }
    end

    def generate_spool_files
      regional_data = valid_records.group_by { |r| r.regional_processing_office.to_sym }

      dir = Dir.mktmpdir

      output = []

      format_records(regional_data).each do |region, records|
        region_id = EducationFacility.facility_for(region: region)

        filename = dir + "/#{region_id}_#{SPOOL_DATE.strftime('%m%d%Y')}_vetsgov.spl"
        contents = records.map(&:text).join(WINDOWS_NOTEPAD_LINEBREAK)

        File.open(filename, 'w') { |file| file.write(contents) }

        output << { count: records.length, region: region, filename: filename }
      end
    end

    def upload_spool_files
      regional_data = valid_records.group_by { |r| r.regional_processing_office.to_sym }

      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO

      writer = SFTPWriter::Factory.get_writer(Settings.edu.sftp).new(Settings.edu.sftp, logger: logger)

      output = []

      format_records(regional_data).each do |region, records|
        next if [:western, :central].exclude?(region)

        region_id = EducationForm::EducationFacility.facility_for(region: region)

        filename = "/#{region_id}_#{SPOOL_DATE.strftime('%m%d%Y')}_vetsgov.spl"
        contents = records.map(&:text).join(EducationForm::WINDOWS_NOTEPAD_LINEBREAK)

        writer.write(contents, filename)

        output << { count: records.length, region: region, filename: filename }
      end
    end

    def valid_records
      EducationBenefitsClaim.includes(:saved_claim)
                            .where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day)
    end

    def malformed_records
      EducationBenefitsClaim.includes(:saved_claim)
                            .where(saved_claims: { created_at: nil })
                            .where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day)
    end

    def malformed_claim_ids
      edu_claims = []
      edu_submissions = []
      saved_claims = []
      confirmation_numbers = []

      malformed_records.find_each do |claim|
        edu_claims << claim.id
        edu_submissions << claim.education_benefits_submission&.id
        saved_claims << claim.saved_claim&.id
        confirmation_numbers << claim.confirmation_number
      end

      {
        education_benefits_claims: edu_claims.compact,
        education_benefits_submissions: edu_submissions.compact,
        saved_claims: saved_claims.compact,
        confirmation_numbers: confirmation_numbers.compact
      }
    end

    def format_records(grouped_data)
      raw_groups = grouped_data.each do |region, v|
        grouped_data[region] = v.map do |record|
          record.saved_claim.valid? && EducationForm::Forms::Base.build(record)
        end.compact
      end

      # delete any regions that only had malformed claims before returning
      raw_groups.delete_if { |_, v| v.empty? }
    end

    def write_confirmation_numbers(confirmation_numbers)
      filename = Dir.mktmpdir + '/confirmation_numbers.txt'
      File.open(filename, 'w') { |f| f.puts(confirmation_numbers) }

      filename
    end
  end
end
