# frozen_string_literal: true
module MVI
  class Response
    attr_accessor :body, :code, :original_response

    RESPONSE_CODES = {
      success: 'AA',
      failure: 'AE',
      invalid_request: 'AR'
    }.freeze

    def initialize(response)
      @body = response.body[:prpa_in201306_uv02]
      @code = @body[:acknowledgement][:type_code][:@code]
      @original_reponse = response.xml
    end

    def invalid?
      @code == RESPONSE_CODES[:invalid_request]
    end

    def failure?
      @code == RESPONSE_CODES[:failure]
    end

    def to_h
      # TODO(AJD): correlation ids should eventually be a hash but need to investigate
      # what all the possible types are
      patient = @body[:control_act_process][:subject][:registration_event][:subject1][:patient]
      {
        correlation_ids: map_correlation_ids(patient[:id]),
        status: patient[:status_code][:@code],
        given_names: patient[:patient_person][:name].first[:given].map(&:capitalize),
        family_name: patient[:patient_person][:name].first[:family].capitalize,
        gender: patient[:patient_person][:administrative_gender_code][:@code],
        dob: patient[:patient_person][:birth_time][:@value],
        ssn: patient[:patient_person][:as_other_i_ds][:id][:@extension].gsub(
          /(\d{3})[^\d]?(\d{2})[^\d]?(\d{4})/,
          '\1-\2-\3'
        )
      }
    end

    private

    # MVI correlation id source id relationships:
    # {source id}^{id type}^{assigning authority}^{assigning facility}^{id status}
    # TODO(AJD): MVI team will be sending the mapping of system identifiers to
    # va systems (e.g. 200VETS = vets.gov, 516 = ?) when we have that we can symbolize the keys
    #
    def map_correlation_ids(ids)
      icn, ids = ids.partition { |id| id[:@extension] =~ /^\w+\^NI\^\w+\^\w+\^\w+$/ }
      ids = ids.map { |id| { id[:@extension][/^\w+\^\w+\^(\w+)/, 1] => id[:@extension] } }
      ids.push('ICN' => icn.first[:@extension])
      ids.reduce({}, :update)
    end
  end
end
