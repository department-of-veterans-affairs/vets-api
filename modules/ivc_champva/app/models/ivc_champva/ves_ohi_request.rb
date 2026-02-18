# frozen_string_literal: true

module IvcChampva
  ##
  # VES request model for 10-7959C OHI (Other Health Insurance) submissions.
  #
  # This model represents the data structure expected by the VES API for OHI form submissions.
  # Field mapping is best-effort based on the 10-7959c form structure. TODOs mark fields
  # requiring VES swagger confirmation.
  #
  # TODO: Consider cloning/refactoring `instance_vars_to_hash` from `VesRequest` for more
  # generic serialization of nested objects in the final implementation this class.
  #
  # @example Standalone submission
  #   ohi_request = VesOhiRequest.new(
  #     application_uuid: SecureRandom.uuid,
  #     beneficiary: { first_name: 'Jane', last_name: 'Doe', ssn: '123456789' }
  #   )
  #
  # @example As a subform of 10-10d
  #   parent_request.add_subform('vha_10_7959c', ohi_request)
  #
  class VesOhiRequest
    FORM_TYPE = 'vha_10_7959c'

    attr_accessor :application_uuid, :transaction_uuid, :person_uuid,
                  :beneficiary, :medicare, :health_insurance, :certification

    ##
    # Initialize a new VES OHI request.
    #
    # @param params [Hash] request parameters
    # @option params [String] :application_uuid unique application identifier
    # @option params [String] :transaction_uuid unique transaction identifier (generated if nil)
    # @option params [String] :person_uuid beneficiary person identifier (for linked submissions)
    # @option params [Hash] :beneficiary beneficiary/applicant information
    # @option params [Array<Hash>] :medicare Medicare coverage details
    # @option params [Array<Hash>] :health_insurance other health insurance policies
    # @option params [Hash] :certification certification/signature information
    def initialize(params = {})
      @application_uuid = params[:application_uuid] || SecureRandom.uuid
      @transaction_uuid = params[:transaction_uuid] || SecureRandom.uuid
      @person_uuid = params[:person_uuid]
      @beneficiary = Beneficiary.new(params[:beneficiary] || {})
      @medicare = (params[:medicare] || []).map { |m| Medicare.new(m) }
      @health_insurance = (params[:health_insurance] || []).map { |hi| HealthInsurance.new(hi) }
      @certification = Certification.new(params[:certification] || {})
    end

    ##
    # Returns the form type identifier.
    #
    # @return [String] the form type constant
    def form_type
      FORM_TYPE
    end

    ##
    # Serializes the request to JSON for VES API submission.
    #
    # TODO: Confirm exact JSON structure with VES swagger spec
    #
    # @return [String] JSON representation of the request
    def to_json(*_args)
      {
        # TODO: Confirm VES expects these top-level field names
        applicationUUID: @application_uuid,
        transactionUUID: @transaction_uuid,
        personUUID: @person_uuid,
        beneficiary: @beneficiary.to_hash,
        medicare: @medicare.map(&:to_hash),
        healthInsurance: @health_insurance.map(&:to_hash),
        certification: @certification.to_hash
      }.compact.to_json
    end

    ##
    # Beneficiary/Applicant information for OHI form.
    #
    # TODO: Consider moving to a shared base class with VesRequest::Beneficiary.
    #
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
        {
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
          childType: @child_type,
          dateOfBirth: @date_of_birth,
          address: @address.to_hash
        }.compact
      end
    end

    ##
    # Medicare coverage details.
    #
    # Maps to `applicants[0].medicare[]` in the form submission.
    # Supports Parts A, B, C (Advantage), and D (Prescription).
    #
    class Medicare
      attr_accessor :plan_type, :medicare_number,
                    :part_a_effective_date, :part_b_effective_date,
                    :part_c_carrier, :part_c_effective_date,
                    :has_pharmacy_benefits, :has_part_d,
                    :part_d_carrier, :part_d_effective_date

      # TODO: Confirm field names with VES swagger spec
      def initialize(params = {})
        @plan_type = params[:plan_type] || params[:medicare_plan_type]
        @medicare_number = params[:medicare_number]
        @part_a_effective_date = params[:part_a_effective_date] || params[:medicare_part_a_effective_date]
        @part_b_effective_date = params[:part_b_effective_date] || params[:medicare_part_b_effective_date]
        @part_c_carrier = params[:part_c_carrier] || params[:medicare_part_c_carrier]
        @part_c_effective_date = params[:part_c_effective_date] || params[:medicare_part_c_effective_date]
        @has_pharmacy_benefits = params[:has_pharmacy_benefits]
        @has_part_d = params[:has_part_d] || params[:has_medicare_part_d]
        @part_d_carrier = params[:part_d_carrier] || params[:medicare_part_d_carrier]
        @part_d_effective_date = params[:part_d_effective_date] || params[:medicare_part_d_effective_date]
      end

      # TODO: Confirm exact JSON field names with VES swagger spec
      def to_hash
        {
          planType: @plan_type,
          medicareNumber: @medicare_number,
          partAEffectiveDate: @part_a_effective_date,
          partBEffectiveDate: @part_b_effective_date,
          partCCarrier: @part_c_carrier,
          partCEffectiveDate: @part_c_effective_date,
          hasPharmacyBenefits: @has_pharmacy_benefits,
          hasPartD: @has_part_d,
          partDCarrier: @part_d_carrier,
          partDEffectiveDate: @part_d_effective_date
        }.compact
      end
    end

    ##
    # Other Health Insurance policy details.
    #
    # Maps to `applicants[0].health_insurance[]` in the form submission.
    #
    class HealthInsurance
      attr_accessor :insurance_type, :medigap_plan, :provider,
                    :effective_date, :expiration_date,
                    :through_employer, :eob, :additional_comments

      # TODO: Confirm field names with VES swagger spec
      def initialize(params = {})
        @insurance_type = params[:insurance_type]
        @medigap_plan = params[:medigap_plan]
        @provider = params[:provider]
        @effective_date = params[:effective_date]
        @expiration_date = params[:expiration_date]
        @through_employer = params[:through_employer]
        @eob = params[:eob]
        @additional_comments = params[:additional_comments]
      end

      # TODO: Confirm exact JSON field names with VES swagger spec
      def to_hash
        {
          insuranceType: @insurance_type,
          medigapPlan: @medigap_plan,
          provider: @provider,
          effectiveDate: @effective_date,
          expirationDate: @expiration_date,
          throughEmployer: @through_employer,
          eob: @eob,
          additionalComments: @additional_comments
        }.compact
      end
    end

    ##
    # Certification/signature information.
    #
    # TODO: Consider moving to a shared base class with VesRequest::Certification.
    #
    class Certification
      attr_accessor :signature, :signature_date, :first_name, :last_name,
                    :middle_initial, :phone_number, :address, :relationship

      def initialize(params = {})
        @signature = params[:signature] || params[:statement_of_truth_signature]
        @signature_date = params[:signature_date] || params[:certification_date]
        @first_name = params[:first_name]
        @last_name = params[:last_name]
        @middle_initial = params[:middle_initial]
        @phone_number = params[:phone_number]
        @relationship = params[:relationship] || params[:certifier_role]
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
        hash[:address] = @address.to_hash if @address
        hash.compact
      end
    end

    ##
    # Address structure.
    #
    # TODO: Consider moving to a shared base class with VesRequest::Address.
    #
    class Address
      attr_accessor :street_address, :city, :state, :zip_code, :country, :province, :postal_code

      def initialize(params = {})
        @street_address = params[:street_address] ||
                          params[:streetAddress] ||
                          params[:street] ||
                          params[:street_combined]
        @city = params[:city]
        @state = params[:state]
        @zip_code = params[:zip_code] || params[:zipCode] || params[:postal_code]
        @country = params[:country]
        @province = params[:province]
        @postal_code = params[:postal_code] || params[:postalCode]
      end

      def to_hash
        hash = {
          streetAddress: @street_address,
          city: @city
        }

        # For USA addresses, include state and zipCode
        if @country.nil? || @country.upcase == 'USA'
          hash[:state] = @state
          hash[:zipCode] = @zip_code
        else
          # For international addresses, include country, province, and postalCode
          hash[:country] = @country
          hash[:province] = @province if @province
          hash[:postalCode] = @postal_code if @postal_code
        end

        hash
      end
    end
  end
end
