# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TransformationVES', type: :request do

  forms = [
    'vha_10_10d.json',
    # 'vha_10_7959f_1.json', # VES does not currently support this form
    # 'vha_10_7959f_2.json', # VES does not currently support this form
    # 'vha_10_7959c.json', # VES does not currently support this form
    # 'vha_10_7959a.json' # VES does not currently support this form
  ]

  #let(:ves_request) { double('IvcChampva::VesRequest') }
  let(:ves_client) { double('IvcChampva::VesApi::Client') }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)
    #allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(ves_request)
    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).with(anything, anything, anything)
    #allow(ves_request).to receive_messages(transaction_uuid: '78444a0b-3ac8-454d-a28d-8d63cddd0d3b',
    #                                       application_uuid: 'test-uuid')
    #allow(ves_request).to receive(:transaction_uuid=)
    #allow(ves_request).to receive(:to_json).and_return('{}')
  end

  after do
    Aws.config = @original_aws_config
  end

  describe 'run this section with both values of champva_retry_logic_refactor expecting identical behavior' do
    retry_logic_refactor_values = [false, true]
    retry_logic_refactor_values.each do |champva_retry_logic_refactor_state|
      describe '#submit with flipper champva_send_to_ves enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
                              .with(:champva_send_to_ves, @current_user)
                              .and_return(true)
          allow(Flipper).to receive(:enabled?)
                              .with(:champva_retry_logic_refactor, @current_user)
                              .and_return(champva_retry_logic_refactor_state)
        end

        forms.each do |form|
          fixture_path = Rails.root.join('modules', 'ivc_champva', 'spec', 'fixtures', 'form_json', form)
          data = JSON.parse(fixture_path.read)

          it 'submits the form and verifies the transformed data going to VES' do
            allow(PersistentAttachments::MilitaryRecords).to receive(:find_by)
                                                               .and_return(double('Record1', created_at: 1.day.ago, id: 'some_uuid', file: double(id: 'file0')))
            allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
              double('response',
                     context: double('context', http_response: double('http_response', status_code: 200)))
            )

            post '/ivc_champva/v1/forms', params: data
            expect(response).to have_http_status(:ok)

            sponsor_address = IvcChampva::VesRequest::Address.new(
              street_address: '1 First Ln',
              city: 'Place',
              state: 'AL',
              zip_code: '12345'
            )

            sponsor = IvcChampva::VesRequest::Sponsor.new(
              person_uuid: '57efab45-b6f3-49d6-a189-9f9ff55552f4',
              first_name: 'Veteran',
              last_name: 'Surname',
              middle_initial: 'B',
              suffix: nil,
              ssn: '222554444',
              va_file_number: '123456789',
              date_of_birth: '1987-02-02',
              date_of_marriage: '2005-04-06',
              is_deceased: 'true',
              date_of_death: '2021-01-08',
              is_death_on_active_service: 'true',
              phone_number: '9876543213',
              address: sponsor_address.to_hash
            )

            beneficiary_1_address = IvcChampva::VesRequest::Address.new(
              street_address: '2 Second St',
              city: 'Town',
              state: 'LA',
              zip_code: '16542'
            )

            beneficiary_1 = IvcChampva::VesRequest::Beneficiary.new(
              person_uuid: '912e09f2-3e1f-4021-ba75-c52d1c1d7c6d',
              first_name: 'Applicant',
              last_name: 'Onceler',
              middle_initial: 'C',
              suffix: nil,
              ssn: '123456644',
              email_address: 'email@address.com',
              phone_number: '6543219877',
              gender: 'FEMALE',
              enrolled_in_medicare: true,
              has_other_insurance: nil,
              relationship_to_sponsor: 'SPOUSE',
              child_type: nil,
              date_of_birth: '1978-03-04',
              address: beneficiary_1_address.to_hash
            )

            beneficiary_2_address = IvcChampva::VesRequest::Address.new(
              street_address: '3 Third Ave',
              city: 'Ville',
              state: 'AR',
              zip_code: '65478'
            )

            beneficiary_2 = IvcChampva::VesRequest::Beneficiary.new(
              person_uuid: '4fd5495b-5b69-46e7-8f13-e8b278a54749',
              first_name: 'Appy',
              last_name: 'Twos',
              middle_initial: 'D',
              suffix: nil,
              ssn: '123664444',
              email_address: 'mailme@domain.com',
              phone_number: '2345698777',
              gender: 'MALE',
              enrolled_in_medicare: true,
              has_other_insurance: true,
              relationship_to_sponsor: 'SPOUSE',
              child_type: nil,
              date_of_birth: '1985-03-10',
              address: beneficiary_2_address.to_hash
            )

            beneficiary_3_address = IvcChampva::VesRequest::Address.new(
              street_address: '4 Third Ave',
              city: 'Mark',
              state: 'AR',
              zip_code: '65478'
            )

            beneficiary_3 = IvcChampva::VesRequest::Beneficiary.new(
              person_uuid: 'e06ab71f-0ec6-4348-af05-7ef9a4f0ead4',
              first_name: 'Homer',
              last_name: 'Simpson',
              middle_initial: 'D',
              suffix: nil,
              ssn: '123664444',
              email_address: 'mailme@homer.com',
              phone_number: '2345698777',
              gender: 'MALE',
              enrolled_in_medicare: true,
              has_other_insurance: true,
              relationship_to_sponsor: 'SPOUSE',
              child_type: nil,
              date_of_birth: '1985-03-10',
              address: beneficiary_3_address.to_hash
            )

            beneficiary_4_address = IvcChampva::VesRequest::Address.new(
              street_address: '426 Ave C',
              city: 'Philadelphia',
              state: 'PA',
              zip_code: '65478'
            )

            beneficiary_4 = IvcChampva::VesRequest::Beneficiary.new(
              person_uuid: '52959722-a6a9-44db-8391-8d1cea47db0a',
              first_name: 'Logan',
              last_name: 'Wolf',
              middle_initial: 'W',
              suffix: nil,
              ssn: '123664444',
              email_address: 'mailme@logan.com',
              phone_number: '2345698777',
              gender: 'MALE',
              enrolled_in_medicare: true,
              has_other_insurance: true,
              relationship_to_sponsor: 'SPOUSE',
              child_type: nil,
              date_of_birth: '1999-03-10',
              address: beneficiary_4_address.to_hash
            )

            beneficiary_5_address = IvcChampva::VesRequest::Address.new(
              street_address: '12345 Play Place',
              city: 'Camden',
              state: 'NJ',
              zip_code: '65478'
            )

            beneficiary_5 = IvcChampva::VesRequest::Beneficiary.new(
              person_uuid: '6f70ada1-9e7b-4887-a7a9-66ab55a074c5',
              first_name: 'Maria',
              last_name: 'Storm',
              middle_initial: 'W',
              suffix: nil,
              ssn: '123664444',
              email_address: 'mailme@Maria.com',
              phone_number: '2345698777',
              gender: 'FEMALE',
              enrolled_in_medicare: true,
              has_other_insurance: true,
              relationship_to_sponsor: 'SPOUSE',
              child_type: nil,
              date_of_birth: '1959-03-10',
              address: beneficiary_5_address.to_hash
            )

            beneficiaries = [
              beneficiary_1,
              beneficiary_2,
              beneficiary_3,
              beneficiary_4,
              beneficiary_5
            ]

            certification = IvcChampva::VesRequest::Certification.new(
              signature: 'GI Joe',
              signature_date: '2021-01-08',
              first_name: 'GI',
              last_name: 'Joe',
              middle_initial: 'Canceled',
              phone_number: '2345698777',
              relationship: 'Agent',
              address: {
                street_address: 'Hasbro',
                city: 'Burbank',
                state: 'CA',
                zip_code: '90041'
              }
            )

            ves_request = IvcChampva::VesRequest.new(
              application_type: 'CHAMPVA_APPLICATION',
              application_uuid: '55459eae-5131-4e70-8622-8a2034758c95',
              sponsor: sponsor.to_hash,
              beneficiaries: beneficiaries.map(&:to_hash),
              certification: certification.to_hash,
              transaction_uuid: '88c36e11-74ff-46b3-b791-3636ae3b6f53'
            )

            expect(ves_client).to have_received(:submit_1010d).with(
              anything, # transaction uuid is auto generated per submission
              'fake-user', # acting_user
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  application_type: 'CHAMPVA_APPLICATION',
                  # application_uuid: anything, # application uuid is auto generated per submission
                  sponsor: an_instance_of(IvcChampva::VesRequest::Sponsor).and(
                    have_attributes(
                      #person_uuid: '57efab45-b6f3-49d6-a189-9f9ff55552f4', # is this auto generated too?
                      first_name: 'Veteran',
                      last_name: 'Surname',
                      middle_initial: 'B',
                      suffix: nil,
                      ssn: '222554444',
                      va_file_number: '123456789',
                      date_of_birth: '1987-02-02',
                      date_of_marriage: '2005-04-06',
                      is_deceased: 'true',
                      date_of_death: '2021-01-08',
                      is_death_on_active_service: 'true',
                      phone_number: '9876543213',
                      address: an_instance_of(IvcChampva::VesRequest::Address).and(
                        have_attributes(
                          street_address: '1 First Ln',
                          city: 'Place',
                          state: 'AL',
                          zip_code: '12345'
                        )
                      )
                    )
                  ),
                  beneficiaries: array_including(
                    an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                      have_attributes(
                        #person_uuid: '912e09f2-3e1f-4021-ba75-c52d1c1d7c6d', # is this auto generated too?
                        first_name: 'Applicant',
                        last_name: 'Onceler',
                        middle_initial: 'C',
                        suffix: nil,
                        ssn: '123456644',
                        email_address: 'email@address.com',
                        phone_number: '6543219877',
                        gender: 'FEMALE',
                        enrolled_in_medicare: true,
                        has_other_insurance: nil,
                        relationship_to_sponsor: 'SPOUSE',
                        child_type: nil,
                        date_of_birth: '1978-03-04',
                        address: an_instance_of(IvcChampva::VesRequest::Address).and(
                          have_attributes(
                            street_address: '2 Second St',
                            city: 'Town',
                            state: 'LA',
                            zip_code: '16542'
                          )
                        )
                      )
                    )
                  ),
                  certification: an_instance_of(IvcChampva::VesRequest::Certification).and(
                    have_attributes(
                      signature: 'GI Joe',
                      signature_date: '2021-01-08',
                      first_name: 'GI',
                      last_name: 'Joe',
                      middle_initial: 'Canceled',
                      phone_number: '2345698777',
                      relationship: 'Agent',
                      address: an_instance_of(IvcChampva::VesRequest::Sponsor).and(
                        have_attributes(
                          street_address: 'Hasbro',
                          city: 'Burbank',
                          state: 'CA',
                          zip_code: '90041'
                        )
                      )
                    )
                  )#,
                  #transaction_uuid: anything # transaction uuid is auto generated per submission
                )
              )
            )
          end


        end
      end
    end
  end



end