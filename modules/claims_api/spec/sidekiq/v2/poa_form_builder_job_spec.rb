# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe ClaimsApi::V2::PoaFormBuilderJob, type: :job do
  subject { described_class }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
  let(:poa_code) { 'ABC' }

  before do
    Sidekiq::Job.clear_all
  end

  describe 'generating and uploading the signed pdf' do
    context '2122a' do
      before do
        power_of_attorney.form_data = {
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: ['DRUG ABUSE', 'SICKLE CELL'],
          veteran: {
            serviceBranch: 'ARMY',
            address: {
              numberAndStreet: '2719 Hyperion Ave',
              city: 'Los Angeles',
              state: 'CA',
              country: 'US',
              zipFirstFive: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          claimant: {
            firstName: 'Lillian',
            middleInitial: 'A',
            lastName: 'Disney',
            email: 'lillian@disney.com',
            relationship: 'Spouse',
            address: {
              numberAndStreet: '2688 S Camino Real',
              city: 'Palm Springs',
              state: 'CA',
              country: 'US',
              zipFirstFive: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          representative: {
            poaCode: poa_code.to_s,
            type: 'SERVICE ORGANIZATION REPRESENTATIVE',
            firstName: 'Bob',
            lastName: 'Representative',
            organizationName: 'I Help Vets LLC',
            address: {
              numberAndStreet: '2719 Hyperion Ave',
              city: 'Los Angeles',
              state: 'CA',
              country: 'US',
              zipFirstFive: '92264'
            }
          }
        }
        power_of_attorney.save
      end

      it 'generates e-signatures correctly' do
        data = power_of_attorney
               .form_data
               .deep_merge(
                 {
                   'veteran' => {
                     'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
                     'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
                     'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
                     'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
                   }
                 }
               )
        final_data = data.merge(
          {
            'text_signatures' => {
              'page1' => [
                {
                  'signature' => 'JESSE GRAY - signed via api.va.gov',
                  'x' => 35,
                  'y' => 73
                },
                {
                  'signature' => 'Bob Representative - signed via api.va.gov',
                  'x' => 35,
                  'y' => 100
                }
              ],
              'page2' => [
                {
                  'signature' => 'JESSE GRAY - signed via api.va.gov',
                  'x' => 35,
                  'y' => 306
                },
                {
                  'signature' => 'Bob Representative - signed via api.va.gov',
                  'x' => 35,
                  'y' => 200
                }
              ]
            }
          }
        )

        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect_any_instance_of(ClaimsApi::V2::PoaPdfConstructor::Individual)
          .to receive(:construct)
          .with(final_data, id: power_of_attorney.id)
          .and_call_original

        subject.new.perform(power_of_attorney.id, '2122A')
      end

      it 'Calls the POA updater job upon successful upload to VBMS' do
        token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
        document_response = OpenStruct.new(upload_document_response: {
          '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
          '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
        }.with_indifferent_access)

        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token).and_return(token_response)
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload_document).and_return(document_response)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })

        expect(ClaimsApi::PoaUpdater).to receive(:perform_async)

        subject.new.perform(power_of_attorney.id, '2122A')
      end
    end

    context '2122' do
      before do
        power_of_attorney.form_data = {
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: ['DRUG ABUSE', 'SICKLE CELL'],
          veteran: {
            address: {
              numberAndStreet: '2719 Hyperion Ave',
              city: 'Los Angeles',
              state: 'CA',
              country: 'US',
              zipFirstFive: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          claimant: {
            firstName: 'Lillian',
            middleInitial: 'A',
            lastName: 'Disney',
            email: 'lillian@disney.com',
            relationship: 'Spouse',
            address: {
              numberAndStreet: '2688 S Camino Real',
              city: 'Palm Springs',
              state: 'CA',
              country: 'US',
              zipFirstFive: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          serviceOrganization: {
            poaCode: poa_code.to_s,
            firstName: 'Bob',
            lastName: 'Representative',
            organizationName: 'I Help Vets LLC',
            address: {
              numberAndStreet: '2719 Hyperion Ave',
              city: 'Los Angeles',
              state: 'CA',
              country: 'US',
              zipFirstFive: '92264'
            }
          }
        }
        power_of_attorney.save
      end

      it 'generates e-signatures correctly' do
        data = power_of_attorney
               .form_data
               .deep_merge(
                 {
                   'veteran' => {
                     'firstName' => power_of_attorney.auth_headers['va_eauth_firstName'],
                     'lastName' => power_of_attorney.auth_headers['va_eauth_lastName'],
                     'ssn' => power_of_attorney.auth_headers['va_eauth_pnid'],
                     'birthdate' => power_of_attorney.auth_headers['va_eauth_birthdate']
                   }
                 }
               )
        final_data = data.merge(
          {
            'text_signatures' => {
              'page2' => [
                {
                  'signature' => 'JESSE GRAY - signed via api.va.gov',
                  'x' => 35,
                  'y' => 240
                },
                {
                  'signature' => 'Bob Representative - signed via api.va.gov',
                  'x' => 35,
                  'y' => 200
                }
              ]
            }
          }
        )

        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect_any_instance_of(ClaimsApi::V2::PoaPdfConstructor::Organization)
          .to receive(:construct)
          .with(final_data, id: power_of_attorney.id)
          .and_call_original

        subject.new.perform(power_of_attorney.id, '2122')
      end

      it 'Calls the POA updater job upon successful upload to VBMS' do
        token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
        document_response = OpenStruct.new(upload_document_response: {
          '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
          '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
        }.with_indifferent_access)

        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token).and_return(token_response)
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload_document).and_return(document_response)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })

        expect(ClaimsApi::PoaUpdater).to receive(:perform_async)

        subject.new.perform(power_of_attorney.id, '2122')
      end
    end
  end

  context 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred for the POA Form Builder Job'
      msg = { 'args' => [power_of_attorney.id, 'value here'],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: power_of_attorney.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end
end
