# frozen_string_literal: true

module EducationForm
  class GenerateSpoolFiles
    SPOOL_DATE = '2017-10-26'.to_date
    WINDOWS_NOTEPAD_LINEBREAK = "\r\n"
    SSN_PREFIX = {
      '1990' => 'veteran',
      '1995' => 'veteran',
      '1990e' => 'relative',
      '5490' => 'veteran',
      '5495' => 'veteran',
      '1990n' => 'veteran'
    }

    def delete_malformed_claims
      malformed = malformed_claim_ids

      filename = write_confirmation_numbers(malformed[:confirmation_numbers])

      count = 0
      count += EducationBenefitsSubmission.delete(malformed[:education_benefits_submissions])
      count += EducationBenefitsClaim.delete(malformed[:education_benefits_claims])
      count += SavedClaim.delete(malformed[:saved_claims])

      { count: count, filename: filename }
    end

    def full_name(name)
      return '' if name.nil?
      [name['first'], name['middle'], name['last'], name['suffix']].compact.join(' ')
    end

    def get_names_and_ssns
      names_and_ssns = []

      valid_records.find_each do |education_benefits_claim|
        next if education_benefits_claim.region == :eastern
        parsed_form = education_benefits_claim.parsed_form

        names_and_ssns << {
          'veteranSocialSecurityNumber' => parsed_form['veteranSocialSecurityNumber'],
          'relativeSocialSecurityNumber' => parsed_form['relativeSocialSecurityNumber'],
          'veteranFullName' => full_name(parsed_form['veteranFullName']),
          'relativeFullName' => full_name(parsed_form['relativeFullName'])
        }
      end

      names_and_ssns
    end

    def generate_spool_files
      output = []

      dir = Dir.mktmpdir

      formatted_regional_data.each do |region, records|
        output << write_local_spool_file(region, records, dir)
      end

      output
    end

    def upload_spool_files
      output = []

      logger = Logger.new(STDOUT)
      logger.level = Logger::INFO
      writer = SFTPWriter::Factory.get_writer(Settings.edu.sftp).new(Settings.edu.sftp, logger: logger)

      formatted_regional_data.each do |region, records|
        output << write_remote_spool_file(region, records, writer)
      end

      output
    end

    def write_local_spool_file(region, records, dir)
      region_id = EducationFacility.facility_for(region: region)

      filename = dir + "/#{region_id}_#{SPOOL_DATE.strftime('%m%d%Y')}_vetsgov.spl"
      contents = records.map(&:text).join(WINDOWS_NOTEPAD_LINEBREAK)

      File.open(filename, 'w') { |file| file.write(contents) }

      { count: records.length, region: region, filename: filename }
    end

    def write_remote_spool_file(region, records, writer)
      region_id = EducationFacility.facility_for(region: region)

      filename = "/#{region_id}_#{SPOOL_DATE.strftime('%m%d%Y')}_vetsgov.spl"
      contents = records.map(&:text).join(WINDOWS_NOTEPAD_LINEBREAK)

      writer.write(contents, filename)

      { count: records.length, region: region, filename: filename }
    end

    # :nocov:
    def formatted_regional_data
      regional_data = valid_records.group_by { |r| r.regional_processing_office.to_sym }

      raw_groups = regional_data.each do |region, v|
        regional_data[region] = v.map do |record|
          record.saved_claim.valid? && EducationForm::Forms::Base.build(record)
        end.compact
      end

      # delete any regions that only had malformed claims before returning
      raw_groups.delete_if { |_, v| v.empty? }
    end

    def valid_records
      EducationBenefitsClaim.where(processed_at: SPOOL_DATE.beginning_of_day..SPOOL_DATE.end_of_day)
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
    # :nocov:

    def write_ssns
      filename = Dir.mktmpdir + '/ssns.txt'
      File.open(filename, 'w') { |f| f.puts(get_ssns) }

      filename
    end

    def write_confirmation_numbers(confirmation_numbers)
      filename = Dir.mktmpdir + '/confirmation_numbers.txt'
      File.open(filename, 'w') { |f| f.puts(confirmation_numbers) }

      filename
    end
  end
end
