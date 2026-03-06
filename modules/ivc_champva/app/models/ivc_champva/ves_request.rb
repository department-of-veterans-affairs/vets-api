# frozen_string_literal: true

##
# Function to get all instance variables from a class and convert them
# to a hash, converting names from snake_case to camelCase symbols.
# Also runs `to_hash` on any existing top-level `address` properties.
#
# Note: @subforms is explicitly excluded as it should never be serialized to VES.
#
def instance_vars_to_hash(instance)
  # Instance variables that should never be serialized to VES
  excluded_vars = %i[@subforms]

  # Create hash where keys are the instance variables with '@' removed and
  # converted from snake_case to camelCase
  # e.g.: '@phone_number' -> :phoneNumber
  instance_vars_hash = instance.instance_variables.each_with_object({}) do |var, hash|
    next if excluded_vars.include?(var)

    key = var.to_s.delete_prefix('@').camelize(:lower).to_sym
    value = instance.instance_variable_get(var)
    hash[key] = value
  end

  if instance.respond_to?(:address) && instance.address.respond_to?(:to_hash)
    instance_vars_hash[:address] = instance.address.to_hash
  end

  instance_vars_hash.compact
end

module IvcChampva
  class VesRequest
    FORM_TYPE = 'vha_10_10d'

    attr_accessor :application_type, :application_uuid, :sponsor, :beneficiaries, :certification, :transaction_uuid,
                  :subforms

    def initialize(params = {})
      @application_type = params[:application_type] || 'CHAMPVA'
      @application_uuid = params[:application_uuid] || SecureRandom.uuid
      @sponsor = Sponsor.new(params[:sponsor] || {})
      @beneficiaries = (params[:beneficiaries] || []).map { |ben| Beneficiary.new(ben) }
      @certification = Certification.new(params[:certification] || {})
      @transaction_uuid = params[:transaction_uuid] || SecureRandom.uuid
      @subforms = []
    end

    ##
    # Adds a subform to be submitted after this request succeeds.
    # Subforms are NOT serialized to VES - they are submitted separately.
    #
    # @param form_type [String] The form type identifier (e.g., 'vha_10_7959c')
    # @param request [Object] The subform request object (e.g., VesOhiRequest)
    def add_subform(form_type, request)
      @subforms << { form_type:, request: }
    end

    ##
    # Returns the form type identifier.
    #
    # @return [String] the form type constant
    def form_type
      FORM_TYPE
    end

    ##
    # Returns true if this request has subforms to submit after the primary request.
    #
    # @return [Boolean]
    def subforms?
      @subforms.any?
    end

    # NOTE: subforms are intentionally NOT included in to_json.
    # They are submitted separately after the primary request succeeds.
    def to_json(*_args)
      {
        applicationType: @application_type,
        applicationUUID: @application_uuid,
        sponsor: @sponsor.to_hash,
        beneficiaries: @beneficiaries.map(&:to_hash),
        certification: @certification.to_hash,
        transactionUUID: @transaction_uuid
      }.to_json
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
        # Camelize doesn't handle 'UUID' properly
        hash = instance_vars_to_hash(self).except(:personUuid)
        hash[:personUUID] = @person_uuid
        hash[:isDeceased] = @is_deceased.nil? ? false : @is_deceased
        hash[:vaFileNumber] = @va_file_number || ''
        hash
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
        @childtype = params[:child_type]
        @date_of_birth = params[:date_of_birth]
        @address = Address.new(params[:address] || {})
      end

      def to_hash
        # Camelize doesn't handle 'UUID' properly
        hash = instance_vars_to_hash(self).except(:personUuid)
        hash[:personUUID] = @person_uuid
        hash
      end
    end

    class Address
      attr_accessor :street_address, :city, :state, :zip_code, :country, :province, :postal_code

      def initialize(params = {})
        @street_address = params[:street_address] || params[:streetAddress]
        @city = params[:city]
        @state = params[:state]
        @zip_code = params[:zip_code] || params[:zipCode]
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
        instance_vars_to_hash(self)
      end
    end
  end
end
