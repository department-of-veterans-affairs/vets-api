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
      prased_form_data = JSON.parse(form_for_user.form_data)
      metadata = form_for_user.metadata

      # If EVSS's list of rated disabilties does not match our prefilled rated disabilites
      if rated_disabilities_evss.present? &&
         names_arr(prased_form_data.dig('ratedDisabilities')) != names_arr(rated_disabilities_evss.rated_disabilities)
        # If the user has viewed the rated disabiltiy page the form data ratedDisabilities will have a "view:selected"
        # key if they've gotten to the ratedDisabilities page or further send them back to the ratedDisabilities page
        # when the list of rated disabilities is updated.
        if prased_form_data['ratedDisabilities'].present? &&
           prased_form_data['ratedDisabilities'][0].keys.include?('view:selected')
          metadata['returnUrl'] = '/disabilities/rated-disabilities'
        end
        evss_rated_disabilites = JSON.parse(rated_disabilities_evss.rated_disabilities.to_json)
        prased_form_data['ratedDisabilities'] = camelize_with_olivebranch(evss_rated_disabilites)
        metadata['ratedDisabilitiesUpdated'] = true
      else
        metadata['ratedDisabilitiesUpdated'] = false
      end

      {
        formData: prased_form_data,
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
