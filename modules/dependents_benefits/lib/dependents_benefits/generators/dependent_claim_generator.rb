# frozen_string_literal: true

module DependentsBenefits
  module Generators
    ##
    # Abstract generator class for creating dependent claims (686c or 674)
    # from a combined 686c-674 form submission.
    #
    # This generator takes the full form_data from a combined submission and
    # creates individual SavedClaim records for each claim type with only
    # the relevant data for that specific claim.
    #
    class DependentClaimGenerator
      def initialize(form_data, parent_id)
        @form_data = form_data
        @parent_id = parent_id
      end

      ##
      # Generates a new SavedClaim with the appropriate form_id and extracted data
      #
      # @return [DependentsBenefits::PrimaryDependencyClaim] The created and validated claim
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
      # @return [DependentsBenefits::PrimaryDependencyClaim] The created and validated claim
      # @raise [ActiveRecord::RecordInvalid] if the claim is invalid
      #
      def create_claim(extracted_data)
        claim = claim_class.new(form: extracted_data.to_json)

        claim.save!
        claim
      end

      ##
      # Create a claim group linking the new claim to the parent claim
      #
      # @param claim [DependentsBenefits::PrimaryDependencyClaim] The newly created claim
      # @return [void]
      #
      def create_claim_group_item(claim)
        parent_claim_group = SavedClaimGroup.by_saved_claim_id(parent_id).first!
        claim_group = SavedClaimGroup.new(claim_group_guid: parent_claim_group.claim_group_guid,
                                          parent_claim_id: parent_id,
                                          saved_claim_id: claim.id)
        claim_group.save!

        claim_group
      end

      ##
      # Return the claim class for this claim type
      # Must be implemented by subclasses
      # @return [Class] The claim class (e.g., DependentsBenefits::PrimaryDependencyClaim)
      # @raise [NotImplementedError] if not implemented by subclass
      #
      def claim_class
        raise NotImplementedError, 'Subclasses must implement claim_class'
      end
    end
  end
end
