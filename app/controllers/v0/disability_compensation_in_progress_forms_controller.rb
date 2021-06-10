# frozen_string_literal: true

module V0
  class DisabilityCompensationInProgressFormsController < InProgressFormsController
    def show
      if form_for_user
        render json: data_and_metadata_with_updated_rated_disabilites
      else
        render json: camelized_prefill_for_user
      end
    end

    private

    def form_id
      FormProfiles::VA526ez::FORM_ID
    end

    def data_and_metadata_with_updated_rated_disabilites
      parsed_form_data = JSON.parse(form_for_user.form_data)
      metadata = form_for_user.metadata

      # If EVSS's list of rated disabilties does not match our prefilled rated disabilites
      if rated_disabilities_evss.present? &&
         names_arr(parsed_form_data.dig('ratedDisabilities')) != names_arr(rated_disabilities_evss.rated_disabilities)
        if parsed_form_data['ratedDisabilities'].present? &&
           parsed_form_data.dig('view:claimType', 'view:claimingIncrease')
          metadata['returnUrl'] = '/disabilities/rated-disabilities'
        end
        evss_rated_disabilites = JSON.parse(rated_disabilities_evss.rated_disabilities.to_json)
        parsed_form_data['updatedRatedDisabilities'] = camelize_with_olivebranch(evss_rated_disabilites)
      end

      {
        formData: parsed_form_data,
        metadata: metadata
      }
    end

    def rated_disabilities_evss
      @rated_disabilities_evss ||= FormProfiles::VA526ez.for(form_id: form_id, user: @current_user)
                                                        .initialize_rated_disabilities_information
    end

    def names_arr(rated_disabilities)
      rated_disabilities&.collect { |rd| rd['name'] }&.sort
    end
  end
end
