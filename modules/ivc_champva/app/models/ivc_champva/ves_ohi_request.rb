# frozen_string_literal: true

module IvcChampva
  ##
  # VES request model for 10-7959C OHI (Other Health Insurance) submissions.
  #
  # This model represents the data structure expected by the VES API for OHI form submissions.
  # Field mappings are based on the VES OHI swagger specification.
  #
  # @example Standalone submission
  #   ohi_request = VesOhiRequest.new(
  #     application_uuid: SecureRandom.uuid,
  #     beneficiary_medicare: { first_name: 'Jane', last_name: 'Doe', ssn: '123456789' }
  #   )
  #
  # @example As a subform of 10-10d
  #   parent_request.add_subform('vha_10_7959c', ohi_request)
  #
  class VesOhiRequest
    FORM_TYPE = 'vha_10_7959c'
    APPLICATION_TYPE = 'CHAMPVA_INS_APPLICATION'

    attr_accessor :application_uuid, :transaction_uuid, :beneficiary_medicare, :certification

    ##
    # Initialize a new VES OHI request.
    #
    # @param params [Hash] request parameters
    # @option params [String] :application_uuid unique application identifier
    # @option params [String] :transaction_uuid unique transaction identifier (generated if nil)
    # @option params [Hash] :beneficiary_medicare combined beneficiary, medicare, and insurance data
    # @option params [Hash] :certification certification/signature information
    def initialize(params = {})
      @application_uuid = params[:application_uuid] || SecureRandom.uuid
      @transaction_uuid = params[:transaction_uuid] || SecureRandom.uuid
      @beneficiary_medicare = BeneficiaryMedicare.new(params[:beneficiary_medicare] || {})
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
    # @return [String] JSON representation of the request
    def to_json(*_args)
      {
        applicationUUID: @application_uuid,
        applicationType: APPLICATION_TYPE,
        beneficiaryMedicare: @beneficiary_medicare.to_hash,
        certification: @certification.to_hash
      }.compact.to_json
    end

    ##
    # Combined beneficiary and Medicare/insurance information for OHI form.
    #
    # This matches the VES swagger schema where beneficiary data, Medicare parts,
    # and other insurances are nested under a single `beneficiaryMedicare` object.
    #
    class BeneficiaryMedicare
      attr_accessor :person_uuid, :first_name, :last_name, :middle_initial,
                    :ssn, :date_of_birth, :address, :medicare_bene_id,
                    :medicare_parts, :other_insurances, :email_address,
                    :phone_number, :gender, :is_new_address

      def initialize(params = {})
        @person_uuid = params[:person_uuid]
        @first_name = params[:first_name]
        @last_name = params[:last_name]
        @middle_initial = params[:middle_initial]
        @ssn = params[:ssn]
        @date_of_birth = params[:date_of_birth]
        @address = Address.new(params[:address] || {})
        @medicare_bene_id = params[:medicare_bene_id] || params[:medicare_number]
        @medicare_parts = (params[:medicare_parts] || []).map { |mp| MedicarePart.new(mp) }
        @other_insurances = (params[:other_insurances] || []).map { |oi| OtherInsurance.new(oi) }
        @email_address = params[:email_address]
        @phone_number = params[:phone_number]
        @gender = params[:gender]
        @is_new_address = params[:is_new_address]
      end

      def to_hash
        {
          personUUID: @person_uuid,
          lastName: @last_name,
          firstName: @first_name,
          middleInitial: @middle_initial,
          ssn: @ssn,
          dateOfBirth: @date_of_birth,
          address: @address.to_hash,
          medicareBeneId: @medicare_bene_id,
          medicareParts: @medicare_parts.map(&:to_hash),
          otherInsurances: @other_insurances.map(&:to_hash),
          emailAddress: @email_address,
          phoneNumber: @phone_number,
          gender: @gender,
          isNewAddress: @is_new_address
        }.compact
      end
    end

    ##
    # Medicare Part information (A, B, D).
    #
    # Maps to VES `medicareParts[]` array structure.
    # VES enum: MEDICARE_PART_A, MEDICARE_PART_B, MEDICARE_PART_D (no Part C)
    #
    class MedicarePart
      attr_accessor :effective_date, :medicare_part_type, :termination_date

      def initialize(params = {})
        @effective_date = params[:effective_date]
        @medicare_part_type = params[:medicare_part_type]
        @termination_date = params[:termination_date]
      end

      def to_hash
        {
          effectiveDate: @effective_date,
          medicarePartType: @medicare_part_type,
          terminationDate: @termination_date
        }.compact
      end

      private

      def normalize_part_type(part_type)
        return nil unless part_type

        PART_TYPE_MAP[part_type.to_s.downcase] || part_type.to_s.upcase
      end
    end

    ##
    # Other Health Insurance policy details.
    #
    # Maps to VES `otherInsurances[]` array structure.
    #
    class OtherInsurance
      # VES enum values for insurancePlanType
      PLAN_TYPE_MAP = {
        'hmo' => 'HMO',
        'ppo' => 'PPO',
        'medicare_advantage' => 'MEDICARE_ADVANTAGE',
        'medicaid' => 'MEDICAID',
        'medigap_plan' => 'MEDIGAP_PLAN',
        'other' => 'OTHER'
      }.freeze

      attr_accessor :insurance_name, :effective_date, :termination_date,
                    :insurance_plan_type, :is_through_employment,
                    :is_prescription_covered, :eob_indicator, :comments

      def initialize(params = {})
        @insurance_name = params[:insurance_name] || params[:provider]
        @effective_date = params[:effective_date]
        @termination_date = params[:termination_date] || params[:expiration_date]
        @insurance_plan_type = normalize_plan_type(params[:insurance_plan_type] || params[:insurance_type])
        @is_through_employment = params[:is_through_employment] || params[:through_employer]
        @is_prescription_covered = params[:is_prescription_covered]
        @eob_indicator = params[:eob_indicator] || params[:eob]
        @comments = params[:comments] || params[:additional_comments]
      end

      def to_hash
        {
          insuranceName: @insurance_name,
          effectiveDate: @effective_date,
          terminationDate: @termination_date,
          insurancePlanType: @insurance_plan_type,
          isThroughEmployment: @is_through_employment,
          isPrescriptionCovered: @is_prescription_covered,
          eobIndicator: @eob_indicator,
          comments: @comments
        }.compact
      end

      private

      def normalize_plan_type(plan_type)
        return nil unless plan_type

        PLAN_TYPE_MAP[plan_type.to_s.downcase] || plan_type.to_s.upcase
      end
    end

    ##
    # Certification/signature information.
    #
    # Based on actual form data, we populate signature, signature_date, and signed_by_other.
    # signed_by_other is derived from certifier_role - true if certifier is not the applicant.
    # Additional swagger fields (firstName, lastName, etc.) are optional and not collected.
    #
    class Certification
      # Possible certifier_role values from form data:
      # - 'applicant': The applicant is signing (signed_by_other = false)
      # - 'sponsor': The veteran/sponsor is signing (signed_by_other = true)
      # - 'other': A third party is signing (signed_by_other = true)
      APPLICANT_ROLE = 'applicant'

      attr_accessor :signature, :signature_date, :signed_by_other

      def initialize(params = {})
        @signature = params[:signature] || params[:statement_of_truth_signature]
        @signature_date = params[:signature_date] || params[:certification_date]
        @signed_by_other = params[:certifier_role]&.to_s&.downcase != APPLICANT_ROLE
      end

      def to_hash
        {
          signature: @signature,
          signatureDate: @signature_date,
          signedbyOther: @signed_by_other
        }.compact
      end
    end

    ##
    # Address structure matching VES swagger schema.
    #
    class Address
      attr_accessor :street_address, :city, :province, :state,
                    :zip_code, :postal_code, :country

      def initialize(params = {})
        @street_address = params[:street_address] ||
                          params[:streetAddress] ||
                          params[:street] ||
                          params[:street_combined]
        @city = params[:city]
        @province = params[:province]
        @state = params[:state]
        @zip_code = params[:zip_code] || params[:zipCode] || params[:postal_code]
        @postal_code = params[:postal_code] || params[:postalCode]
        @country = params[:country]
      end

      def to_hash
        {
          streetAddress: @street_address,
          city: @city,
          province: @province,
          state: @state,
          zipCode: @zip_code,
          postalCode: @postal_code,
          country: @country
        }.compact
      end
    end
  end
end
