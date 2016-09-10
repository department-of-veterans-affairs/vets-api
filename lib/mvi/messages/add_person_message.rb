require 'ox'
require_relative 'message_builder'

module MVI
  module Messages
    class AddPersonMessage
      include MVI::Messages::MessageBuilder
      EXTENSION = 'PRPA_IN201301UV02'.freeze

      def build(vcid, first_name, last_name, dob, ssn)
        @message = idm(EXTENSION)
        header(vcid, EXTENSION)
        add_person_body(patient_person(first_name, last_name, dob, ssn))
        @doc << @message
        Ox.dump(@doc)
      end

      def add_person_body(patient_person)
        control_act_process = control_act_process()
        subject = element('subject', typeCode: 'SUBJ')
        registration_event = element('registrationEvent', classCode: 'REG', moodCode: 'EVN')
        registration_event << element('id', nullFlavor: 'UNK')
        registration_event << element('statusCode', code: 'active')
        subject1 = element('subject1', typeCode: 'SBJ')
        patient = element('patient', classCode: 'PAT')
        patient << element('id', nullFlavor: 'UNK')
        patient << element('statusCode', code: 'active')
        patient << patient_person
        subject1 << patient
        registration_event << subject1
        subject << registration_event
        control_act_process << subject
        @message << control_act_process
      end

      def control_act_process
        el = element('controlActProcess', classCode: 'CACT', moodCode: 'EVN')
        el << element('code', code: 'PRPA_TE201305UV02', codeSystem: '2.16.840.1.113883.1.6')
        el
      end

      def patient_person(first_name, last_name, dob, ssn)
        patient_person = element('patientPerson')
        name = element('name', use: 'L')
        name << element('given', text!: first_name)
        name << element('family', text!: last_name)
        patient_person << name
        patient_person << element('birthTime', value: dob.strftime('%Y%m%d'))
        patient_person << ssn_id(ssn)
      end

      def ssn_id(ssn)
        ssn_id = element('asOtherIDs ', classCode: 'SSN')
        ssn_id << element('id', extension: ssn, root: '2.16.840.1.113883.4.1')
        scoping_org = element('scopingOrganization', classCode: 'ORG', determinerCode: 'INSTANCE')
        scoping_org << element('id', root: '2.16.840.1.113883.4.1')
        ssn_id << scoping_org
      end
    end
  end
end
