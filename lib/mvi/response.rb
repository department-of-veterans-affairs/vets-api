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
      patient = @body[:control_act_process][:subject][:registration_event][:subject1][:patient]
      {
        status: patient[:status_code][:@code],
        given_names: patient[:patient_person][:name].first[:given].map(&:capitalize),
        family_name: patient[:patient_person][:name].first[:family].capitalize,
        gender: patient[:patient_person][:administrative_gender_code][:@code],
        birth_date: patient[:patient_person][:birth_time][:@value],
        ssn: patient[:patient_person][:as_other_i_ds][:id][:@extension]
      }.merge(map_correlation_ids(patient[:id]))
    end

    private

    # MVI correlation id source id relationships:
    # {source id}^{id type}^{assigning authority}^{assigning facility}^{id status}
    # NI = national identifier, PI = patient identifier
    def map_correlation_ids(ids)
      {
        icn: select_extension(ids, /^\w+\^NI\^\w+\^\w+\^\w+$/, '2.16.840.1.113883.4.349'),
        mhv: select_extension(ids, /^\w+\^PI\^200MHV\^\w+\^\w+$/, '2.16.840.1.113883.4.349'),
        edipi: select_extension(ids, /^\w+\^NI\^200DOD\^USDOD\^\w+$/, '2.16.840.1.113883.3.364')
      }
    end

    def select_extension(ids, pattern, root)
      ids.select do |id|
        id[:@extension] =~ pattern && id[:@root] == root
      end.first[:@extension]
    end
  end
end
