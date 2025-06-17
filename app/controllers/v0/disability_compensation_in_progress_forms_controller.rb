# frozen_string_literal: true

module V0
  class DisabilityCompensationInProgressFormsController < InProgressFormsController
    service_tag 'disability-application'

    def show
      if form_for_user
        # get IPF
        data = data_and_metadata_with_updated_rated_disabilities
        log_started_form_version(data, 'get IPF')
      else
        # create IPF
        data = camelized_prefill_for_user
        log_started_form_version(data, 'create IPF')
      end
      render json: data
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
         arr_to_compare(rated_disabilities_evss.rated_disabilities.map(&:attributes))

        if parsed_form_data['ratedDisabilities'].present? &&
           parsed_form_data.dig('view:claimType', 'view:claimingIncrease')
          metadata['returnUrl'] = '/disabilities/rated-disabilities'
        end
        evss_rated_disabilities = JSON.parse(rated_disabilities_evss.rated_disabilities.to_json)
        parsed_form_data['updatedRatedDisabilities'] = camelize_with_olivebranch(evss_rated_disabilities)
      end

      # for Toxic Exposure 1.1 - add indicator to In Progress Forms
      # moving forward, we don't want to change the version if it is already there
      parsed_form_data = set_started_form_version(parsed_form_data)
      {
        formData: parsed_form_data,
        metadata:
      }
    end

    def set_started_form_version(data)
      if data['started_form_version'].blank? || data['startedFormVersion'].blank?
        log_started_form_version(data, 'existing IPF missing startedFormVersion')
        data['startedFormVersion'] = '2019'
      end
      data
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

    # temp: for https://github.com/department-of-veterans-affairs/va.gov-team/issues/97932
    # tracking down a possible issue with prefill
    def log_started_form_version(data, location)
      cloned_data = data.deep_dup
      cloned_data_as_json = cloned_data.as_json.deep_transform_keys { |k| k.camelize(:lower) }

      if cloned_data_as_json['formData'].present?
        started_form_version = cloned_data_as_json['formData']['startedFormVersion']
        message = "Form526 InProgressForm startedFormVersion = #{started_form_version} #{location}"
        Rails.logger.info(message)
      end

      if started_form_version.blank?
        raise Common::Exceptions::ServiceError.new(
          detail: "no startedFormVersion detected in #{location}",
          source: 'DisabilityCompensationInProgressFormsController#show'
        )
      end
    rescue => e
      Rails.logger.error("Form526 InProgressForm startedFormVersion retrieval failed #{location} #{e.message}")
    end
  end
end
