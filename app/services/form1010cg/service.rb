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

    def fetch_and_build_metadata(claim)
      form_data = claim.parsed_form
      metadata = {}

      # Add find the ICN for each person on the form
      mvi_searches.each do |mvi_search|
        icn_present_in_metadata = metadata.dig(mvi_search.namespace.to_sym, :icn).present?
        form_subject_present = form_data[mvi_search.namespace].present?

        next if !form_subject_present && mvi_search.optional?
        next if icn_present_in_metadata

        response = search_mvi_for(mvi_search, form_data, !icn_present_in_metadata)

        metadata[mvi_search.namespace.to_sym] = { icn: response&.profile&.icn } if response&.status == 'OK'
      end

      metadata
    end

    private

    def search_mvi_for(mvi_search, form_data, raise_if_not_found)
      identity = build_user_identity form_data, mvi_search.namespace

      begin
        response = mvi.find_profile identity
      rescue MVI::Errors::RecordNotFound
        raise_unprocessable(claim) if mvi_search.assertIcnPresence? && raise_if_not_found
      end

      response
    end

    def raise_unprocessable(claim)
      claim.errors.add(
        :base,
        "#{mvi_search.namespace}NotFound".snakecase.to_sym,
        message: "#{mvi_search.namespace.titleize} could not be found in the VA's system"
      )

      raise(Common::Exceptions::ValidationErrors, claim)
    end

    def form_schema_id
      SavedClaim::CaregiversAssistanceClaim::FORM
    end

    def mvi
      @mvi ||= MVI::Service.new
    end

    # MVI::Service requires a valid UserIdentity to run a profile search on. This UserIdentity should not be persisted.
    def build_user_identity(parsed_form_data, namespace)
      data = parsed_form_data[namespace]

      attributes = {
        first_name: data['fullName']['first'],
        middle_name: data['fullName']['middle'],
        last_name: data['fullName']['last'],
        birth_date: data['dateOfBirth'],
        gender: data['gender'] == 'U' ? nil : data['gender'],
        ssn: data['ssnOrTin'],
        email: data['email'] || 'no-email@example.com',
        uuid: SecureRandom.uuid,
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      }

      UserIdentity.new attributes
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
