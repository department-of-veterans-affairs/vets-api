# frozen_string_literal: true

module DependentsBenefits
  ##
  # Abstract factory class for creating dependent claims (686c or 674)
  # from a combined 686c-674 form submission.
  #
  # This factory takes the full form_data from a combined submission and
  # creates individual SavedClaim records for each claim type with only
  # the relevant data for that specific claim.
  #
  class DependentClaimFactory
    def initialize(form_data, parent_id)
      @form_data = form_data
      @parent_id = parent_id
    end

    ##
    # Generates a new SavedClaim with the appropriate form_id and extracted data
    #
    # @return [DependentsBenefits::SavedClaim] The created and validated claim
    # @raise [ActiveRecord::RecordInvalid] if the claim is invalid
    #
    def generate
      extracted_data = extract_form_data
      claim = create_claim(extracted_data)
      create_claim_group_item(claim)
      claim
    end

    private

    attr_reader :form_data, :parent_id

    ##
    # Extract the relevant form data for this specific claim type
    # Must be implemented by subclasses
    #
    # @return [Hash] The extracted form data
    # @raise [NotImplementedError] if not implemented by subclass
    #
    def extract_form_data
      raise NotImplementedError, 'Subclasses must implement extract_form_data'
    end

    ##
    # Create the SavedClaim with the extracted data
    #
    # @param extracted_data [Hash] The form data specific to this claim type
    # @return [DependentsBenefits::SavedClaim] The created and validated claim
    # @raise [ActiveRecord::RecordInvalid] if the claim is invalid
    #
    def create_claim(extracted_data)
      claim = DependentsBenefits::SavedClaim.new(
        form: extracted_data.to_json,
        form_id:
      )

      claim.save!
      claim
    end

    ##
    # Create a claim group linking the new claim to the parent claim
    # TODO: Implement claim grouping functionality when requirements are finalized
    #
    # @param claim [DependentsBenefits::SavedClaim] The newly created claim
    # @return [void]
    #
    def create_claim_group_item(claim)
      # Stubbed out - will be implemented when claim grouping requirements are defined
      Rails.logger.info "TODO: Link claim #{claim.id} to parent #{parent_id}"
    end

    ##
    # Return the form_id for this claim type
    # Must be implemented by subclasses
    #
    # @return [String] The form_id
    # @raise [NotImplementedError] if not implemented by subclass
    #
    def form_id
      raise NotImplementedError, 'Subclasses must implement form_id'
    end
  end
end
