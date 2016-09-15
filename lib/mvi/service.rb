require 'savon'

module MVI
  class Service
    extend Savon::Model

    client wsdl: "#{ENV['MVI_FILE_PATH']}/IdmWebService_200VGOV.wsdl"

    operations :prpa_in201301_uv02, :prpa_in201302_uv02, :prpa_in201305_uv02

    RESPONSE_CODES = {
      success: 'AA',
      failure: 'AE',
      invalid_request: 'AR'
    }.freeze

    def self.prpa_in201305_uv02(first_name, last_name, dob, ssn)
      message = MVI::Messages::FindCandidateMessage.build(first_name, last_name, dob, ssn)
      response = super(xml: message)
      body = response.body[:prpa_in201306_uv02]
      code = body[:acknowledgement][:type_code][:@code]
      return invalid_request_handler(body) if code == RESPONSE_CODES[:invalid_request]
      return failure_request_handler(body) if code == RESPONSE_CODES[:failure]
      return formatted_response(body)
    end

    def self.invalid_request_handler(body)
      raise MVI::InvalidRequestError.new
    end

    def self.failure_request_handler(body)
      raise MVI::RequestFailureError.new
    end

    def self.formatted_response(body)
      patient = body[:control_act_process][:subject][:registration_event][:subject1][:patient]
      {
        correlation_ids: patient[:id].map { |id| id[:@extension] },
        status: patient[:status_code][:@code],
        first_name: patient[:patient_person][:name].first[:given].capitalize,
        last_name: patient[:patient_person][:name].first[:family].capitalize,
        gender: patient[:patient_person][:administrative_gender_code][:@code],
        dob: patient[:patient_person][:birth_time][:@value],
        ssn: patient[:patient_person][:as_other_i_ds][:id][:@extension].gsub(/(\d{3})[^\d]?(\d{2})[^\d]?(\d{4})/, '\1-\2-\3')
      }
    end

    singleton_class.send(:alias_method, :find_candidate, :prpa_in201305_uv02)
  end
  class RequestFailureError < StandardError;
  end
  class InvalidRequestError < StandardError;
  end
end
