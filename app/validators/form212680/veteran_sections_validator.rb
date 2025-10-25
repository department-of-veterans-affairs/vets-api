# frozen_string_literal: true

module Form212680
  class VeteranSectionsValidator
    attr_reader :errors

    def initialize(sections)
      @sections = sections
      @errors = []
    end

    def valid?
      validate_veteran_information
      validate_claimant_information
      validate_benefit_information
      validate_veteran_signature

      @errors.empty?
    end

    private

    def validate_veteran_information
      info = @sections['veteranInformation']

      if info.blank?
        @errors << 'Veteran information is required'
        return
      end

      validate_veteran_name(info)
      validate_veteran_ssn(info)
      validate_veteran_file_number(info)
      validate_veteran_dob(info)
    end

    def validate_claimant_information
      info = @sections['claimantInformation']

      if info.blank?
        @errors << 'Claimant information is required'
        return
      end

      validate_claimant_name(info)
      validate_claimant_relationship(info)
      validate_claimant_address(info)
    end

    def validate_benefit_information
      info = @sections['benefitInformation']

      if info.blank?
        @errors << 'Benefit information is required'
        nil
      end
    end

    def validate_veteran_signature
      signature = @sections['veteranSignature']

      if signature.blank?
        @errors << 'Veteran signature is required'
        return
      end

      @errors << 'Signature is required' if signature['signature'].blank?
      validate_signature_date(signature)
    end

    def valid_ssn?(ssn)
      # Remove any non-digit characters
      clean_ssn = ssn.to_s.gsub(/\D/, '')

      # Must be exactly 9 digits
      clean_ssn.length == 9
    end

    def valid_date?(date_string)
      Date.parse(date_string.to_s)
      true
    rescue ArgumentError
      false
    end

    def valid_claim_type?(claim_type)
      ['Aid and Attendance', 'Housebound', 'aid and attendance', 'housebound'].include?(claim_type)
    end

    def validate_veteran_name(info)
      if info['fullName'].blank?
        @errors << 'Veteran full name is required'
      else
        name = info['fullName']
        @errors << 'Veteran first name is required' if name['first'].blank?
        @errors << 'Veteran last name is required' if name['last'].blank?
      end
    end

    def validate_veteran_ssn(info)
      if info['ssn'].blank?
        @errors << 'Veteran Social Security Number is required'
      elsif !valid_ssn?(info['ssn'])
        @errors << 'Invalid Social Security Number format'
      end
    end

    def validate_veteran_file_number(info)
      @errors << 'Veteran VA file number is required' if info['vaFileNumber'].blank?
    end

    def validate_veteran_dob(info)
      if info['dateOfBirth'].blank?
        @errors << 'Veteran date of birth is required'
      elsif !valid_date?(info['dateOfBirth'])
        @errors << 'Invalid date of birth format'
      end
    end

    def validate_claimant_name(info)
      if info['fullName'].blank?
        @errors << 'Claimant full name is required'
      else
        name = info['fullName']
        @errors << 'Claimant first name is required' if name['first'].blank?
        @errors << 'Claimant last name is required' if name['last'].blank?
      end
    end

    def validate_claimant_relationship(info)
      @errors << 'Claimant relationship to veteran is required' if info['relationship'].blank?
    end

    def validate_claimant_address(info)
      if info['address'].blank?
        @errors << 'Claimant address is required'
      else
        address = info['address']
        @errors << 'Claimant street address is required' if address['street'].blank?
        @errors << 'Claimant city is required' if address['city'].blank?
        @errors << 'Claimant state is required' if address['state'].blank?
        @errors << 'Claimant ZIP code is required' if address['zipCode'].blank?
      end
    end

    def validate_signature_date(signature)
      if signature['date'].blank?
        @errors << 'Signature date is required'
      elsif !valid_date?(signature['date'])
        @errors << 'Invalid signature date format'
      else
        check_signature_date_range(signature['date'])
      end
    end

    def check_signature_date_range(date_string)
      sig_date = begin
        Date.parse(date_string)
      rescue
        nil
      end
      return unless sig_date

      @errors << 'Signature date must be within the last 60 days' if sig_date < 60.days.ago.to_date
      @errors << 'Signature date cannot be in the future' if sig_date > Time.zone.today
    end
  end
end
