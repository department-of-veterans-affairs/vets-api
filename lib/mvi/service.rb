require 'savon'

module MVI
  class Service
    def self.add_person
    end

    def self.update_person
    end

    def self.find_candidate(vcid, first_name, last_name, dob, ssn)
      message_builder = MVI::Messages::FindCandidateMessage.new
      message = message_builder.build(vcid, first_name, last_name, dob, ssn)
      client.call(MVI::Messages::FindCandidateMessage::EXTENSION, message: message)
    end

    def self.client
      @client ||= Savon.client(wsdl: ENV['MVI_WSDL'])
    end
  end
end
