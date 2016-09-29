# frozen_string_literal: true
# rubocop:disable MethodLength
def mvi_savon_valid_response
  instance_double(
    'Savon::Response',
    body: {
      prpa_in201306_uv02: {
        id: {
          :@extension => 'WSDOC1609131753362231779394902',
          :@root => '2.16.840.1.113883.4.349'
        },
        creation_time: { :@value => '20160913175336' },
        version_code: { :@code => '3.0' },
        interaction_id: { :@extension => 'PRPA_IN201306UV02', :@root => '2.16.840.1.113883.1.6' },
        processing_code: { :@code => 'T' },
        processing_mode_code: { :@code => 'T' },
        accept_ack_code: { :@code => 'NE' },
        receiver:
          { device:
            { id: { :@extension => '200VGOV', :@root => '2.16.840.1.113883.4.349' },
              :@determiner_code => 'INSTANCE',
              :@class_code => 'DEV' },
            :@type_code => 'RCV' },
        sender:
          { device:
            { id: { :@extension => '200M', :@root => '2.16.840.1.113883.4.349' },
              :@determiner_code => 'INSTANCE',
              :@class_code => 'DEV' },
            :@type_code => 'SND' },
        acknowledgement:
          {
            type_code: { :@code => 'AA' },
            target_message:
              { id:
                { :@extension => 'MCID-12345', :@root => '1.2.840.114350.1.13.0.1.7.1.1' } },
            acknowledgement_detail:
              [
                {
                  code:
                    {
                      :@code_system_name => 'MVI', :@code => '132', :@display_name => 'IMT'
                    },
                  text: 'Identity Match Threshold'
                },
                {
                  code: {
                    :@code_system_name => 'MVI', :@code => '120', :@display_name => 'PDT'
                  },
                  text: 'Potential Duplicate Threshold'
                }
              ]
          },
        control_act_process:
          { code:
            { :@code_system => '2.16.840.1.113883.1.6', :@code => 'PRPA_TE201306UV02' },
            subject:
              { registration_event:
                { id: { :@null_flavor => 'NA' },
                  status_code: { :@code => 'active' },
                  subject1:
                    { patient:
                      { id:
                        [
                          {
                            :@extension => '1000123456V123456^NI^200M^USVHA^P',
                            :@root => '2.16.840.1.113883.4.349'
                          },
                          {
                            :@extension => '12345^PI^516^USVHA^PCE',
                            :@root => '2.16.840.1.113883.4.349'
                          },
                          {
                            :@extension => '2^PI^553^USVHA^PCE',
                            :@root => '2.16.840.1.113883.4.349'
                          },
                          {
                            :@extension => '12345^PI^200HD^USVHA^A',
                            :@root => '2.16.840.1.113883.4.349'
                          },
                          {
                            :@extension => 'TKIP123456^PI^200IP^USVHA^A',
                            :@root => '2.16.840.1.113883.4.349'
                          },
                          {
                            :@extension => '123456^PI^200MHV^USVHA^A',
                            :@root => '2.16.840.1.113883.4.349'
                          },
                          {
                            :@extension => '1234^NI^200DOD^USDOD^A',
                            :@root => '2.16.840.1.113883.3.364'
                          }
                        ],
                        status_code: { :@code => 'active' },
                        patient_person:
                          { name:
                            [
                              {
                                given: %w(JOHN WILLIAM),
                                family: 'SMITH',
                                prefix: 'MR',
                                suffix: 'SR',
                                :@use => 'L'
                              },
                              {
                                delimiter: '101',
                                family: 'SMITH',
                                :@use => 'P'
                              },
                              {
                                family: 'SMITH',
                                :@use => 'C'
                              }
                            ],
                            administrative_gender_code: { :@code => 'M' },
                            birth_time: { :@value => '19800101' },
                            multiple_birth_ind: { :@value => 'true' },
                            as_other_i_ds:
                              { id:
                                { :@extension => '555443333', :@root => '2.16.840.1.113883.4.1' },
                                scoping_organization:
                                  { id: { :@root => '1.2.840.114350.1.13.99997.2.3412' },
                                    :@determiner_code => 'INSTANCE',
                                    :@class_code => 'ORG' },
                                :@class_code => 'SSN' },
                            birth_place:
                              { addr:
                                { city: 'JOHNSON CITY', state: 'MS', country: 'USA' } } },
                        subject_of1:
                          { query_match_observation:
                            { code: { :@code => 'IHE_PDQ' },
                              value: { :@value => '162', :'@xsi:type' => 'INT' },
                              :@class_code => 'COND',
                              :@mood_code => 'EVN' } },
                        :@class_code => 'PAT' },
                      :@type_code => 'SBJ' },
                  custodian:
                    { assigned_entity:
                      { id: { :@root => '2.16.840.1.113883.4.349' },
                        :@class_code => 'ASSIGNED' },
                      :@type_code => 'CST' },
                  :@class_code => 'REG',
                  :@mood_code => 'EVN' },
                :@type_code => 'SUBJ' },
            query_ack:
              { query_id: { :@extension => '18204', :@root => '2.16.840.1.113883.3.933' },
                query_response_code: { :@code => 'OK' },
                result_current_quantity: { :@value => '1' } },
            query_by_parameter:
              { query_id: { :@extension => '18204', :@root => '2.16.840.1.113883.3.933' },
                status_code: { :@code => 'new' },
                modify_code: { :@code => 'MVI.COMP1' },
                initial_quantity: { :@value => '1' },
                parameter_list:
                  { living_subject_name:
                    { value: { given: %w(John William), family: 'Smith', :@use => 'L' },
                      semantics_text: 'LivingSubject.name' },
                    living_subject_birth_time:
                      { value: { :@value => '19800101' },
                        semantics_text: 'LivingSubject..birthTime' },
                    living_subject_id:
                      { value:
                        { :@extension => '555-44-3333', :@root => '2.16.840.1.113883.4.1' },
                        semantics_text: 'SSN' } } },
            :@class_code => 'CACT',
            :@mood_code => 'EVN' },
        :@xmlns => 'urn:hl7-org:v3',
        :'@xmlns:idm' => 'http://vaww.oed.oit.va.gov',
        :'@xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        :@its_version => 'XML_1.0',
        :'@xsi:schema_location' =>
          'urn:hl7-org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/PRPA_IN201306UV02.xsd'
      }
    },
    xml: File.read("#{Rails.root}/spec/support/mvi/find_candidate_response.xml")
  )
end

def mvi_savon_invalid_response
  xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_invalid_response.xml")
  bad_response('AR', xml)
end

def mvi_savon_failure_response
  xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_failure_response.xml")
  bad_response('AE', xml)
end

def bad_response(code, xml)
  instance_double(
    'Savon::Response',
    body: {
      prpa_in201306_uv02: {
        acknowledgement: { type_code: { :@code => code } }
      }
    },
    xml: xml
  )
end
