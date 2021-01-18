# frozen_string_literal: true

module V0
  class DisabilityCompensationInProgressFormsController < InProgressFormsController
    def show
      if form_for_user

        form_profile = FormProfiles::VA526ez.for(form_id: FormProfiles::VA526ez::FORM_ID, user: @current_user)
        rated_disabilities_evss = form_profile.initialize_rated_disabilities_information.rated_disabilities

        form_data = JSON.parse(form_for_user.form_data)

        unless sorted_names(form_data.dig('ratedDisabilities')) == sorted_names(rated_disabilities_evss)
          # todo
        end
        render json: form_for_user.data_and_metadata
      else
        render json: camelized_prefill_for_user
      end
    end

    private

    def sorted_names(rated_disabilities)
      rated_disabilities.collect { |rd| rd['name'] }.sort
    end
  end
end
