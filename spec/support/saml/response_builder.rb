# frozen_string_literal: true

module SAML
  class ResponseBuilder
    include RSpec::Mocks::ExampleMethods

    attr_reader :type, :level

    LEVELS = {
      'loa1' => '1',
      'loa3' => '3',
      'myhealthevet_loa3' => '3',
      'dslogon_loa3' => '3',
      'myhealthevet_multifactor' => '3',
      'dslogon_multifactor' => '3'
    }.freeze

    def initialize(type:, level: nil)
      @type = type
      @level = level
    end

    def self.saml_response(type, level = nil)
      level ||= LEVELS.fetch(type, '1')
      new(type: type, level: level).saml_response
    end

    def self.saml_response_from_attributes(type, attributes)
      new(type: type).saml_response(attributes)
    end

    def saml_response(attributes = saml_attributes)
      decrypted_document_partial = REXML::Document.new(authn_context_xml_partial)
      instance_double(OneLogin::RubySaml::Response, attributes: attributes,
                                                    decrypted_document: decrypted_document_partial,
                                                    is_a?: true,
                                                    is_valid?: true)
    end

    def authn_context_xml_partial
      <<-XML
      <?xml version="1.0"?>
      <samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">
        <saml:Assertion>
          <saml:AuthnStatement>
            <saml:AuthnContext>
              <saml:AuthnContextClassRef>#{authn_context}</saml:AuthnContextClassRef>
            </saml:AuthnContext>
          </saml:AuthnStatement>
        </saml:Assertion>
      </samlp:Response>
      XML
    end

    def authn_context
      case type
      when 'loa1'
        'http://idmanagement.gov/ns/assurance/loa/1/vets'
      when 'loa3'
        'http://idmanagement.gov/ns/assurance/loa/3/vets'
      else
        type
      end
    end

    # rubocop:disable Metrics/MethodLength
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
          'dslogon_idvalue' => ['111223333']
        )
      when 'loa1', 'loa3', 'dslogon_loa3', 'myhealthevet_loa3', 'myhealthevet_multifactor', 'dslogon_multifactor'
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'email'              => ['kam+tristanmhv@adhocteam.us'],
          'fname'              => ['Tristan'],
          'lname'              => ['MHV'],
          'mname'              => [''],
          'social'             => ['111223333'],
          'gender'             => ['male'],
          'birth_date'         => ['1735-10-30'],
          'level_of_assurance' => [level],
          'multifactor'        => [true]
        )
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
