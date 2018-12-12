module SAML
  class ResponseBuilder
    include RSpec::Mocks::ExampleMethods

    attr_reader :type, :level

    def initialize(type:, level:)
      @type = type
      @level = level
    end

    def self.saml_response(type, level)
      new(type: type, level: level).saml_response
    end

    def saml_response
      response_partial = File.read("#{::Rails.root}/spec/fixtures/files/saml_responses/#{response_file}")
      decrypted_document_partial = REXML::Document.new(response_partial)
      instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes,
                                                    decrypted_document: decrypted_document_partial,
                                                    is_a?: true,
                                                    is_valid?: true)
    end

    def response_file
      case type
      when 'myhealthevet'
        'mhv.xml'
      when 'dslogon'
        'dslogon.xml'
      when 'idme'
        level == 1 ? 'loa1.xml' : 'loa3.xml'
      end
    end

    def saml_attributes
      case type
      when 'myhealthevet'
        OneLogin::RubySaml::Attributes.new(
          'mhv_icn' => ['1012853550V207686'],
          'mhv_profile' => ["{\"accountType\":\"#{level}\"}"],
          'mhv_uuid' => ['12345748'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => [false],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'level_of_assurance' => []
        )
      when 'idme'
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'email'              => ['kam+tristanmhv@adhocteam.us'],
          'fname'              => ['Tristan'],
          'lname'              => ['MHV'],
          'mname'              => [''],
          'social'             => ['11122333'],
          'gender'             => ['male'],
          'birth_date'         => ['1735-10-30'],
          'level_of_assurance' => [level],
          'multifactor'        => [true]
        )
      when 'dslogon'
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => ['DEPENDENT'],
          'dslogon_assurance' => [level],
          'dslogon_gender' => ['M'],
          'dslogon_deceased' => ['false'],
          'dslogon_idtype' => ['ssn'],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'dslogon_uuid' => ['1606997570'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => ['true'],
          'level_of_assurance' => ['3'],
          'dslogon_birth_date' => [],
          'dslogon_fname' => ['Tristan'],
          'dslogon_lname' => ['MHV'],
          'dslogon_mname' => [''],
          'dslogon_idvalue' => ['11122333']
        )
      end
    end
  end
end
