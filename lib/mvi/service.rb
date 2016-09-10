require 'savon'

module MVI
  class Service
    extend Savon::Model

    client wsdl: ENV['MVI_WSDL_PATH']

    operations :prpa_in201301_uv02, :prpa_in201302_uv02, :prpa_in201305_uv02

    def self.prpa_in201301_uv02(vcid, first_name, last_name, dob, ssn)
      message = MVI::Messages::AddPersonMessage.build(vcid, first_name, last_name, dob, ssn)
      super(xml: message)
    end
    alias add_person prpa_in201301_uv02

    def self.prpa_in201305_uv02(first_name, last_name, dob, ssn)
      message = MVI::Messages::FindCandidateMessage.build(first_name, last_name, dob, ssn)
      super(xml: message)
    end
    alias find_candidate prpa_in201305_uv02
  end
end
