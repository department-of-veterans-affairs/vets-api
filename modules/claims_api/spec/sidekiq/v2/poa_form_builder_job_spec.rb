# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe ClaimsApi::V2::PoaFormBuilderJob, type: :job, vcr: 'bgs/person_web_service/find_by_ssn' do
  subject { described_class }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
  let(:poa_code) { 'ABC' }
  let(:rep) do
    create(:representative, representative_id: '1234', poa_codes: [poa_code], first_name: 'Bob',
                            last_name: 'Representative')
  end

  before do
    Sidekiq::Job.clear_all
    allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return false
    allow_any_instance_of(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_use_bd).and_return false
  end

  it 'sets retry_for to 48 hours' do
    expect(described_class.get_sidekiq_options['retry_for']).to eq(48.hours)
  end

  describe 'generating and uploading the signed pdf' do
    context '2122a veteran claimant' do
      before do
        power_of_attorney.form_data = {
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
          veteran: {
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          representative: {
            poaCode: poa_code.to_s,
            registrationNumber: '1234',
            type: 'ATTORNEY',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            }
          }
        }
        power_of_attorney.save
      end

      it 'generates e-signatures correctly for a veteran claimant' do
        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
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
                 .deep_merge(
                   {
                     'appointmentDate' => power_of_attorney.created_at
                   }
                 )
          final_data = data.deep_merge(
            {
              'text_signatures' => {
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
              },
              'representative' => {
                'firstName' => 'Bob',
                'lastName' => 'Representative'
              }
            }
          )

          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
          expect_any_instance_of(ClaimsApi::V2::PoaPdfConstructor::Individual)
            .to receive(:construct)
            .with(final_data, id: power_of_attorney.id)
            .and_call_original

          subject.new.perform(power_of_attorney.id, '2122A', 'post',
                              rep.id)
        end
      end

      it 'Calls the POA updater job upon successful upload to VBMS' do
        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
          token_response = OpenStruct.new(upload_token: '<{573F054F-E9F7-4BF2-8C66-D43ADA5C62E7}')
          document_response = OpenStruct.new(upload_document_response: {
            '@new_document_version_ref_id' => '{52300B69-1D6E-43B2-8BEB-67A7C55346A2}',
            '@document_series_ref_id' => '{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}'
          }.with_indifferent_access)

          allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:fetch_upload_token).and_return(token_response)
          allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload_document).and_return(document_response)
          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })

          expect(ClaimsApi::PoaUpdater).to receive(:perform_async)

          subject.new.perform(power_of_attorney.id, '2122A', 'post',
                              rep.id)
        end
      end
    end

    context '2122a non-veteran claimant' do
      before do
        power_of_attorney.form_data = {
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
          veteran: {
            serviceBranch: 'ARMY',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          claimant: {
            claimantId: '1012830872V584140',
            email: 'lillian@disney.com',
            relationship: 'Spouse',
            address: {
              addressLine1: '2688 S Camino Real',
              city: 'Palm Springs',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            },
            firstName: 'Mitchell',
            lastName: 'Jenkins'
          },
          representative: {
            poaCode: poa_code.to_s,
            registrationNumber: '1234',
            type: 'SERVICE ORGANIZATION REPRESENTATIVE',
            firstName: 'Bob',
            lastName: 'Representative',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            }
          }
        }
        power_of_attorney.save
      end

      it 'generates e-signatures correctly for a non-veteran claimant' do
        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
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
                 .deep_merge(
                   {
                     'appointmentDate' => power_of_attorney.created_at
                   }
                 )
          final_data = data.deep_merge(
            {
              'text_signatures' => {
                'page2' => [
                  {
                    'signature' => 'Mitchell Jenkins - signed via api.va.gov',
                    'x' => 35,
                    'y' => 306
                  },
                  {
                    'signature' => 'Bob Representative - signed via api.va.gov',
                    'x' => 35,
                    'y' => 200
                  }
                ]
              },
              'representative' => {
                'firstName' => 'Bob',
                'lastName' => 'Representative'
              }
            }
          )

          allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
          expect_any_instance_of(ClaimsApi::V2::PoaPdfConstructor::Individual)
            .to receive(:construct)
            .with(final_data, id: power_of_attorney.id)
            .and_call_original

          subject.new.perform(power_of_attorney.id, '2122A', 'post',
                              rep.id)
        end
      end
    end

    context '2122 veteran claimant' do
      let!(:org) { create(:organization, name: 'I Help Vets LLC', poa: poa_code) }

      before do
        power_of_attorney.form_data = {
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
          veteran: {
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          serviceOrganization: {
            poaCode: poa_code.to_s,
            registrationNumber: '1234',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
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
               .deep_merge(
                 {
                   'appointmentDate' => power_of_attorney.created_at
                 }
               )
        final_data = data.deep_merge(
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
            },
            'serviceOrganization' => {
              'firstName' => 'Bob',
              'lastName' => 'Representative',
              'organizationName' => 'I Help Vets LLC'
            }
          }
        )

        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
          expect_any_instance_of(ClaimsApi::V2::PoaPdfConstructor::Organization)
            .to receive(:construct)
            .with(final_data, id: power_of_attorney.id)
            .and_call_original

          subject.new.perform(power_of_attorney.id, '2122', 'post',
                              rep.id)
        end
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
        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
          expect(ClaimsApi::PoaUpdater).to receive(:perform_async)

          subject.new.perform(power_of_attorney.id, '2122', 'post',
                              rep.id)
        end
      end
    end

    context '2122 non-veteran claimant' do
      let!(:org) { create(:organization, name: 'I Help Vets LLC', poa: poa_code) }

      before do
        power_of_attorney.form_data = {
          recordConsent: true,
          consentAddressChange: true,
          consentLimits: %w[DRUG_ABUSE SICKLE_CELL],
          veteran: {
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            }
          },
          claimant: {
            claimantId: '1012830872V584140',
            email: 'lillian@disney.com',
            relationship: 'Spouse',
            address: {
              addressLine1: '2688 S Camino Real',
              city: 'Palm Springs',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
            },
            phone: {
              areaCode: '555',
              phoneNumber: '5551337'
            },
            firstName: 'Mitchell',
            lastName: 'Jenkins'
          },
          serviceOrganization: {
            poaCode: poa_code.to_s,
            registrationNumber: '1234',
            address: {
              addressLine1: '2719 Hyperion Ave',
              city: 'Los Angeles',
              stateCode: 'CA',
              country: 'US',
              zipCode: '92264'
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
               .deep_merge(
                 {
                   'appointmentDate' => power_of_attorney.created_at
                 }
               )
        final_data = data.deep_merge(
          {
            'text_signatures' => {
              'page2' => [
                {
                  'signature' => 'Mitchell Jenkins - signed via api.va.gov',
                  'x' => 35,
                  'y' => 240
                },
                {
                  'signature' => 'Bob Representative - signed via api.va.gov',
                  'x' => 35,
                  'y' => 200
                }
              ]
            },
            'serviceOrganization' => {
              'firstName' => 'Bob',
              'lastName' => 'Representative',
              'organizationName' => 'I Help Vets LLC'
            }
          }
        )

        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        VCR.use_cassette('claims_api/mpi/find_candidate/valid_icn_full') do
          expect_any_instance_of(ClaimsApi::V2::PoaPdfConstructor::Organization)
            .to receive(:construct)
            .with(final_data, id: power_of_attorney.id)
            .and_call_original

          subject.new.perform(power_of_attorney.id, '2122', 'post',
                              rep.id)
        end
      end
    end

    context 'when the benefits documents upload feature flag is enabled' do
      let(:output_path) { 'some.pdf' }

      before do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_use_bd).and_return true
        pdf_constructor_double = instance_double(ClaimsApi::V2::PoaPdfConstructor::Organization)
        allow_any_instance_of(ClaimsApi::V2::PoaFormBuilderJob).to receive(:pdf_constructor)
          .and_return(pdf_constructor_double)
        allow(pdf_constructor_double).to receive(:construct).and_return(output_path)
        allow_any_instance_of(ClaimsApi::V2::PoaFormBuilderJob).to receive(:data).and_return({})
      end

      it 'calls the Benefits Documents uploader instead of VBMS' do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_api_poa_uploads_bd_refactor).and_return false
        expect_any_instance_of(ClaimsApi::VBMSUploader).not_to receive(:upload_document)
        expect_any_instance_of(ClaimsApi::BD).to receive(:upload)
        subject.new.perform(power_of_attorney.id, '2122', 'post',
                            rep.id)
      end
    end

    context 'when the BD upload and BD refactor feature flags are enabled' do
      let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-22/signed_filled_final.pdf' }

      before do
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_use_bd).and_return true
        allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_api_poa_uploads_bd_refactor).and_return true
        pdf_constructor_double = instance_double(ClaimsApi::V2::PoaPdfConstructor::Organization)
        allow_any_instance_of(ClaimsApi::V2::PoaFormBuilderJob).to receive(:pdf_constructor)
          .and_return(pdf_constructor_double)
        allow(pdf_constructor_double).to receive(:construct).and_return(pdf_path)
        allow_any_instance_of(ClaimsApi::V2::PoaFormBuilderJob).to receive(:data).and_return({})
        allow_any_instance_of(ClaimsApi::PoaDocumentService).to receive(:create_upload)
          .with(poa: power_of_attorney, pdf_path:, doc_type: 'L190', action: 'post').and_call_original
      end

      it 'calls the Benefits Documents upload_document instead of upload' do
        expect_any_instance_of(ClaimsApi::VBMSUploader).not_to receive(:upload_document)
        expect_any_instance_of(ClaimsApi::BD).to receive(:upload_document)
        subject.new.perform(power_of_attorney.id, '2122', 'post', rep.id)
      end
    end
  end

  describe 'updating process' do
    let(:pdf_path) { 'modules/claims_api/spec/fixtures/21-22/signed_filled_final.pdf' }

    before do
      allow_any_instance_of(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_use_bd).and_return true
      allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_api_poa_uploads_bd_refactor).and_return true
      pdf_constructor_double = instance_double(ClaimsApi::V2::PoaPdfConstructor::Organization)
      allow_any_instance_of(ClaimsApi::V2::PoaFormBuilderJob).to receive(:pdf_constructor)
        .and_return(pdf_constructor_double)
      allow(pdf_constructor_double).to receive(:construct).and_return(pdf_path)
      allow_any_instance_of(ClaimsApi::V2::PoaFormBuilderJob).to receive(:data).and_return({})
    end

    context 'when the pdf is successfully uploaded' do
      before do
        allow_any_instance_of(ClaimsApi::PoaDocumentService).to receive(:create_upload)
          .with(poa: power_of_attorney, pdf_path:, doc_type: 'L190', action: 'post').and_return(nil)
      end

      it 'updates the process for the power of attorney with the success status' do
        subject.new.perform(power_of_attorney.id, '2122', 'post', rep.id)
        expect(ClaimsApi::Process.find_by(processable: power_of_attorney,
                                          step_type: 'PDF_SUBMISSION').step_status).to eq('SUCCESS')
      end
    end

    context 'when the pdf is not successfully uploaded' do
      before do
        allow_any_instance_of(ClaimsApi::PoaDocumentService).to receive(:create_upload)
          .with(poa: power_of_attorney, pdf_path:, doc_type: 'L190', action: 'post').and_raise(Errno::ENOENT, 'error')
      end

      it 'updates the process for the power of attorney with the failed status' do
        subject.new.perform(power_of_attorney.id, '2122', 'post', rep.id)
        expect(ClaimsApi::Process.find_by(processable: power_of_attorney,
                                          step_type: 'PDF_SUBMISSION').step_status).to eq('FAILED')
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
