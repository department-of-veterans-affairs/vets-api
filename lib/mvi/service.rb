require 'savon'

module MVI
  class Service
    extend Savon::Model

    client wsdl: "#{ENV['MVI_FILE_PATH']}/IdmWebService_200VGOV.wsdl"

    operations :prpa_in201301_uv02, :prpa_in201302_uv02, :prpa_in201305_uv02

    def self.prpa_in201305_uv02(first_name, last_name, dob, ssn)
      message = MVI::Messages::FindCandidateMessage.build(first_name, last_name, dob, ssn)
      response = super(xml: message)
      # puts response.inspect
      # puts response.to_hash
      # puts response.body
      # puts response.xml
      response
    end

    singleton_class.send(:alias_method, :find_candidate, :prpa_in201305_uv02)
  end
end
