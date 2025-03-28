# frozen_string_literal: true

module IvcChampva
  class VesRequest
    attr_accessor :application_type, :application_uuid, :sponsor, :beneficiaries, :certification

    def initialize(params = {})
      @application_type = params[:application_type] || 'CHAMPVA'
      @application_uuid = params[:application_uuid] || SecureRandom.uuid
      @sponsor = Sponsor.new(params[:sponsor] || {})
      @beneficiaries = (params[:beneficiaries] || []).map { |ben| Beneficiary.new(ben) }
      @certification = Certification.new(params[:certification] || {})
    end

    def to_json(*_args)
      {
        applicationType: @application_type,
        applicationUUID: @application_uuid,
        sponsor: @sponsor.to_hash,
        beneficiaries: @beneficiaries.map(&:to_hash),
        certification: @certification.to_hash
      }
    end

    class Sponsor
      attr_accessor :first_name, :last_name, :middle_initial, :suffix, :ssn, :va_file_number,
                    :date_of_birth, :date_of_marriage, :date_of_death, :is_deceased,
                    :is_death_on_active_service, :phone_number, :address, :person_uuid

      def initialize(params = {})
        @person_uuid = params[:person_uuid]
        @first_name = params[:first_name]
        @last_name = params[:last_name]
        @middle_initial = params[:middle_initial]
        @suffix = params[:suffix]
        @ssn = params[:ssn]
        @va_file_number = params[:va_file_number] || params[:va_claim_number]
        @date_of_birth = params[:date_of_birth]
        @date_of_marriage = params[:date_of_marriage]
        @is_deceased = params[:is_deceased] || params[:sponsor_is_deceased]
        @date_of_death = params[:date_of_death]
        @is_death_on_active_service = params[:is_death_on_active_service] || false
        @phone_number = params[:phone_number]
        @address = Address.new(params[:address] || {})
      end

      def to_hash
        hash = {
          personUUID: @person_uuid,
          firstName: @first_name,
          lastName: @last_name,
          middleInitial: @middle_initial,
          suffix: @suffix,
          ssn: @ssn,
          vaFileNumber: @va_file_number || '',
          dateOfBirth: @date_of_birth,
          dateOfMarriage: @date_of_marriage,
          isDeceased: @is_deceased.nil? ? false : @is_deceased,
          dateOfDeath: @date_of_death,
          isDeathOnActiveService: @is_death_on_active_service,
          address: @address.to_hash
        }
        hash.compact
      end
    end

    class Beneficiary
      attr_accessor :first_name, :last_name, :middle_initial, :suffix, :ssn, :email_address,
                    :phone_number, :gender, :enrolled_in_medicare,
                    :has_other_insurance, :relationship_to_sponsor, :child_type,
                    :date_of_birth, :address, :person_uuid

      def initialize(params = {})
        @person_uuid = params[:person_uuid]
        @first_name = params[:first_name]
        @last_name = params[:last_name]
        @middle_initial = params[:middle_initial]
        @suffix = params[:suffix]
        @ssn = params[:ssn]
        @email_address = params[:email_address]
        @phone_number = params[:phone_number]
        @gender = params[:gender]
        @enrolled_in_medicare = params[:enrolled_in_medicare]
        @has_other_insurance = params[:has_other_insurance]
        @relationship_to_sponsor = params[:relationship_to_sponsor]
        @child_type = params[:child_type]
        @date_of_birth = params[:date_of_birth]
        @address = Address.new(params[:address] || {})
      end

      def to_hash
        hash = {
          personUUID: @person_uuid,
          firstName: @first_name,
          lastName: @last_name,
          middleInitial: @middle_initial,
          suffix: @suffix,
          ssn: @ssn,
          emailAddress: @email_address,
          phoneNumber: @phone_number,
          gender: @gender,
          enrolledInMedicare: @enrolled_in_medicare,
          hasOtherInsurance: @has_other_insurance,
          relationshipToSponsor: @relationship_to_sponsor,
          childtype: @child_type,
          dateOfBirth: @date_of_birth,
          address: @address.to_hash
        }
        hash.compact
      end
    end

    class Address
      attr_accessor :street_address, :city, :state, :zip_code

      def initialize(params = {})
        @street_address = params[:street_address] || params[:streetAddress] || DEFAULT_ADDRESS[:street_address]
        @city = params[:city] || DEFAULT_ADDRESS[:city]
        @state = params[:state] || DEFAULT_ADDRESS[:state]
        @zip_code = params[:zip_code] || params[:zipCode] || DEFAULT_ADDRESS[:zip_code]
      end

      def to_hash
        {
          streetAddress: @street_address,
          city: @city,
          state: @state,
          zipCode: @zip_code
        }
      end
    end

    class Certification
      attr_accessor :signature, :signature_date, :first_name, :last_name,
                    :middle_initial, :phone_number, :address, :relationship

      def initialize(params = {})
        @signature = params[:signature]
        @signature_date = params[:signature_date]
        @first_name = params[:first_name]
        @last_name = params[:last_name]
        @middle_initial = params[:middle_initial]
        @phone_number = params[:phone_number]
        @relationship = params[:relationship]
        @address = params[:address].present? ? Address.new(params[:address]) : nil
      end

      def to_hash
        hash = {
          signature: @signature,
          signatureDate: @signature_date,
          firstName: @first_name,
          lastName: @last_name,
          middleInitial: @middle_initial,
          phoneNumber: @phone_number,
          relationship: @relationship
        }

        # Only include address if it was provided
        hash[:address] = @address.to_hash if @address

        hash.compact
      end
    end
  end
end
