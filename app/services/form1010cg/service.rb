# frozen_string_literal: true

# This service manages the interactions between CaregiversAssistanceClaim, CARMA, and Form1010cg::Submission.
module Form1010cg
  class Service
    def submit_claim!(claim_data)
      claim = SavedClaim::CaregiversAssistanceClaim.new(claim_data)
      claim.valid? || raise(Common::Exceptions::ValidationErrors, claim)

      carma_submission = CARMA::Models::Submission.from_claim(claim)
      carma_submission.metadata = fetch_and_build_metadata(claim)

      carma_submission.submit!

      Form1010cg::Submission.new(
        carma_case_id: carma_submission.carma_case_id,
        submitted_at: carma_submission.submitted_at
      )
    end

    private

    # Destroy this form it has previously been stored in-progress by this user_context
    def form_schema_id
      SavedClaim::CaregiversAssistanceClaim::FORM
    end

    def mvi
      @mvi ||=  MVI::Service.new
    end

    def fetch_and_build_metadata(claim)
      form_data = claim.parsed_form
      metadata = {}

      # Add find the ICN for each person on the form
      mvi_searches.each do |mvi_search|
        next if form_data[mvi_search.namespace].nil? && mvi_search.optional?

        attributes = build_mvi_profile_search(form_data, mvi_search.namespace)
        response = mvi.find_profile_by_attributes_only(attributes)

        metadata[mvi_search.namespace.to_sym] = { icn: response&.profile&.icn } if response.status == 'OK'

        # If person cannot be found in MVI, raise a Common::Exceptions::ValidationErrors
        if mvi_search.assertIcnPresence? && metadata[mvi_search.namespace.to_sym][:icn].nil?
          claim.errors.add(
            :base,
            "#{mvi_search.namespace}NotFound".snakecase.to_sym,
            message: "#{mvi_search.namespace.titleize} could not be found in the VA's system"
          )

          raise(Common::Exceptions::ValidationErrors, claim)
        end
      end

      metadata
    end

    def build_mvi_profile_search(parsed_form_data, namespace)
      data = parsed_form_data[namespace]

      OpenStruct.new(
        first_name: data['fullName']['first'],
        middle_name: data['fullName']['middle'],
        last_name: data['fullName']['last'],
        birth_date: data['dateOfBirth'],
        gender: data['gender'],
        ssn: data['ssnOrTin']
      )
    end

    def mvi_searches
      [
        OpenStruct.new(namespace: 'veteran', optional?: false, assertIcnPresence?: true),
        OpenStruct.new(namespace: 'primaryCaregiver', optional?: false),
        OpenStruct.new(namespace: 'secondaryCaregiverOne', optional?: true),
        OpenStruct.new(namespace: 'secondaryCaregiverTwo', optional?: true)
      ]
    end
  end
end
