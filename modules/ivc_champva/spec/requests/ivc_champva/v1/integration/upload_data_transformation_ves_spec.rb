# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TransformationVES', type: :request do
  forms = [
    'vha_10_10d.json'
    # 'vha_10_7959f_1.json', # VES does not currently support this form
    # 'vha_10_7959f_2.json', # VES does not currently support this form
    # 'vha_10_7959c.json', # VES does not currently support this form
    # 'vha_10_7959a.json' # VES does not currently support this form
  ]

  let(:ves_client) { double('IvcChampva::VesApi::Client') }

  before do
    @original_aws_config = Aws.config.dup
    Aws.config.update(stub_responses: true)
    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).with(anything, anything, anything)
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
              .and_return(double('Record1', created_at: 1.day.ago,
                                            id: 'some_uuid', file: double(id: 'file0')))
            allow_any_instance_of(Aws::S3::Client).to receive(:put_object).and_return(
              double('response',
                     context: double('context', http_response: double('http_response', status_code: 200)))
            )

            post '/ivc_champva/v1/forms', params: data
            expect(response).to have_http_status(:ok)

            # check the base attributes on the call to submit_1010d and the VesRequest object
            expect(ves_client).to have_received(:submit_1010d).with(
              anything, # transaction uuid may be auto generated per submission
              'fake-user', # acting_user
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  application_type: 'CHAMPVA_APPLICATION',
                  application_uuid: anything, # application uuid may be auto generated per submission
                  transaction_uuid: anything # transaction uuid may be auto generated per submission
                )
              )
            )

            # check the attributes on VesRequest::Sponsor
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  sponsor: an_instance_of(IvcChampva::VesRequest::Sponsor).and(
                    have_attributes(
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
                  )
                )
              )
            )

            # check the attributes on VesRequest::Beneficiaries item one
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  beneficiaries: array_including(
                    an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                      have_attributes(
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
                  )
                )
              )
            )

            # check the attributes on VesRequest::Beneficiaries item two
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  beneficiaries: array_including(
                    an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                      have_attributes(
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
                        address: an_instance_of(IvcChampva::VesRequest::Address).and(
                          have_attributes(
                            street_address: '3 Third Ave',
                            city: 'Ville',
                            state: 'AR',
                            zip_code: '65478'
                          )
                        )
                      )
                    )
                  )
                )
              )
            )

            # check the attributes on VesRequest::Beneficiaries item three
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  beneficiaries: array_including(
                    an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                      have_attributes(
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
                        address: an_instance_of(IvcChampva::VesRequest::Address).and(
                          have_attributes(
                            street_address: '4 Third Ave',
                            city: 'Mark',
                            state: 'AR',
                            zip_code: '65478'
                          )
                        )
                      )
                    )
                  )
                )
              )
            )

            # check the attributes on VesRequest::Beneficiaries item four
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  beneficiaries: array_including(
                    an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                      have_attributes(
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
                        address: an_instance_of(IvcChampva::VesRequest::Address).and(
                          have_attributes(
                            street_address: '426 Ave C',
                            city: 'Philadelphia',
                            state: 'PA',
                            zip_code: '65478'
                          )
                        )
                      )
                    )
                  )
                )
              )
            )

            # check the attributes on VesRequest::Beneficiaries item five
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  beneficiaries: array_including(
                    an_instance_of(IvcChampva::VesRequest::Beneficiary).and(
                      have_attributes(
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
                        address: an_instance_of(IvcChampva::VesRequest::Address).and(
                          have_attributes(
                            street_address: '12345 Play Place',
                            city: 'Camden',
                            state: 'NJ',
                            zip_code: '65478'
                          )
                        )
                      )
                    )
                  )
                )
              )
            )

            # check the attributes on VesRequest::Certification
            expect(ves_client).to have_received(:submit_1010d).with(
              anything,
              anything,
              an_instance_of(IvcChampva::VesRequest).and(
                have_attributes(
                  certification: an_instance_of(IvcChampva::VesRequest::Certification).and(
                    have_attributes(
                      signature: 'GI Joe',
                      signature_date: '2021-01-08',
                      first_name: 'GI',
                      last_name: 'Joe',
                      middle_initial: 'Canceled',
                      phone_number: '2345698777',
                      relationship: 'Agent',
                      address: an_instance_of(IvcChampva::VesRequest::Address).and(
                        have_attributes(
                          street_address: 'Hasbro',
                          city: 'Burbank',
                          state: 'CA',
                          zip_code: '90041'
                        )
                      )
                    )
                  )
                )
              )
            )
          end
        end
      end
    end
  end
end
