# frozen_string_literal: true

module V0
  class DisabilityCompensationInProgressFormsController < InProgressFormsController
    def show
      if form_for_user
        render json: data_and_metadata_with_updated_rated_disabilities
      else
        render json: camelized_prefill_for_user
      end
    end

    private

    def form_id
      FormProfiles::VA526ez::FORM_ID
    end

    def data_and_metadata_with_updated_rated_disabilities
      parsed_form_data = JSON.parse(form_for_user.form_data)
      metadata = form_for_user.metadata

      # If EVSS's list of rated disabilities does not match our prefilled rated disabilities
      if rated_disabilities_evss.present? &&
         arr_to_compare(parsed_form_data['ratedDisabilities']) !=
         arr_to_compare(rated_disabilities_evss.rated_disabilities)

        if parsed_form_data['ratedDisabilities'].present? &&
           parsed_form_data.dig('view:claimType', 'view:claimingIncrease')
          metadata['returnUrl'] = '/disabilities/rated-disabilities'
        end
        evss_rated_disabilities = JSON.parse(rated_disabilities_evss.rated_disabilities.to_json)
        parsed_form_data['updatedRatedDisabilities'] = camelize_with_olivebranch(evss_rated_disabilities)
      end

      {
        formData: parsed_form_data,
        metadata:
      }
    end

    def rated_disabilities_evss
      @rated_disabilities_evss ||= FormProfiles::VA526ez.for(form_id:, user: @current_user)
                                                        .initialize_rated_disabilities_information
    rescue
      # if the call to EVSS fails we can skip updating. EVSS fails around an hour each night.
      nil
    end

    def arr_to_compare(rated_disabilities)
      rated_disabilities&.collect do |rd|
        diagnostic_code = rd['diagnostic_code'] || rd['diagnosticCode']
        rated_disability_id = rd['rated_disability_id'] || rd['ratedDisabilityId']
        "#{diagnostic_code}#{rated_disability_id}#{rd['name']}"
      end&.sort
    end
  end
end
