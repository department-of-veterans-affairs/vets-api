require 'ox'

module MVI
  class MessageBuilder
    attr_reader :doc

    SITE_KEY = 'ABC123'.freeze
    ROOT_ID = '2.16.840.1.113883.4.349'.freeze
    INTERACTION_ID = '^PN^200VETS^USDVA'.freeze
    EXTENSIONS = {
      add_person: 'PRPA_IN201301UV02',
      find_candidate: 'PRPA_IN201305UV02',
      update_person: 'PRPA_IN201302UV02'
    }.freeze

    def initialize
      @doc = Ox::Document.new(:version => '1.0')
    end

    def build_find_candidate(vcid, first_name, last_name, dob, ssn)
      @message = xml_tag('PRPA_IN201305UV02')
      header(vcid, EXTENSIONS[:find_candidate])
      find_candidate_body(parameter_list(first_name, last_name, dob, ssn))
      @doc << @message
      Ox.dump(@doc)
    end

    def header(vcid, extension)
      @message << element('id', root: ROOT_ID, extension: "#{vcid}#{INTERACTION_ID}")
      @message << element('creationTime', value: Time.now.utc.strftime('%Y%m%d%M%H%M%S'))
      @message << element('interactionId', root: ROOT_ID, extension: extension)
      @message << element('processingCode', code: Rails.env.production? ? 'P' : 'D')
      @message << element('processingModeCode', code: 'T')
      @message << element('acceptAckCode', code: 'AL')
      receiver = element('receiver', typeCode: 'RCV')
      device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
      id = element('id', root: ROOT_ID)
      device << id
      receiver << device
      @message << receiver
      sender = element('sender', typeCode: 'SND')
      device = element('device', classCode: 'DEV', determinerCode: 'INSTANCE')
      sender << device
      id = element('id', root: ROOT_ID, extension: SITE_KEY)
      sender << id
      @message << sender
    end

    private

    def element(name, attrs = nil)
      el = Ox::Element.new(name)
      return el unless attrs
      attrs.each { |k, v| k == :text! ? el.replace_text(v) : el[k] = v }
      el
    end

    def xml_tag(operation_id)
      element(operation_id,
        xmlns: 'urn:hl7‐org:v3',
        :'xmlns:ps' => 'http://vaww.oed.oit.va.gov',
        :'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema‐instance",
        :'xsi:schemaLocation' => 'urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/PRPA_IN201305UV02.xsd',
        ITSVersion: 'XML_1.0'
      )
    end

    def find_candidate_body(parameter_list)
      control_act_process = control_act_process()
      query_by_parameter = query_by_parameter()
      query_by_parameter << parameter_list
      control_act_process << query_by_parameter
      @message << control_act_process
    end

    def query_by_parameter
      el = element('queryByParameter')
      el << element('queryId', root: '2.16.840.1.113883.3.933', extension: '18204')
      el << element('statusCode', code: 'new')
      el << element('initialValue', value: 1)
      el
    end

    def parameter_list(first_name, last_name, dob, ssn)
      el = element('parameterList')
      el << living_subject_name(first_name, last_name)
      el << living_subject_birth_time(dob)
      el << living_subject_id(ssn)
      el
    end

    def control_act_process
      el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
      el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
      el
    end

    def living_subject_name(first_name, last_name)
      el = element('livingSubjectName')
      value = element('value', use: 'L')
      value << element('given', text!: first_name)
      value << element('family', text!: last_name)
      el << value
    end

    def living_subject_birth_time(dob)
      el = element('livingSubjectBirthTime')
      el << element('value', value: dob.strftime('%Y%m%d'))
      el << element('semanticsText', text!: 'LivingSubject..birthTime')
      el
    end

    def living_subject_id(ssn)
      el = element('livingSubjectId')
      el << element('value', root: '2.16.840.1.113883.4.1', extention: ssn)
      el << element('semanticsText', text!: 'SSN')
      el
    end
  end
end
