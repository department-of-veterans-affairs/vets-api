# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe ClaimsApi::OneOff::PoaV1PdfGenFixupJob, type: :job, vcr: 'bgs/person_web_service/find_by_ssn' do
  subject { described_class }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }
  let(:poa_code) { 'ABC' }
  let(:bad_b64_image) { File.read('modules/claims_api/spec/fixtures/signature_b64_prefix_bad.txt') }
  let(:log_tag) { described_class::LOG_TAG }

  before do
    Flipper.disable(:lighthouse_claims_api_poa_use_bd)
    Sidekiq::Job.clear_all
    allow_any_instance_of(ClaimsApi::V2::BenefitsDocuments::Service)
      .to receive(:get_auth_token).and_return('some-value-here')
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    power_of_attorney.form_data = {
      recordConsent: true,
      consentAddressChange: true,
      consentLimits: ['DRUG ABUSE', 'SICKLE CELL'],
      signatures: {
        veteran: b64_image,
        representative: b64_image
      },
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
      serviceOrganization: {
        poaCode: poa_code.to_s,
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

  describe 'generating the filled and signed pdf' do
    context 'when representative is part of an organization' do
      before do
        create(:veteran_representative, representative_id: '67890', poa_codes: [poa_code.to_s]).save!
        create(:veteran_organization, poa: 'ABC', name: 'Some org')
      end

      it 'generates the pdf to match example & logs success' do
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        expect(ClaimsApi::V1::PoaPdfConstructor::Organization).to receive(:new).and_call_original
        expect_any_instance_of(ClaimsApi::V1::PoaPdfConstructor::Organization).to receive(:construct).and_call_original
        expect_any_instance_of(ClaimsApi::PoaDocumentService).to receive(:create_upload)
        expect(ClaimsApi::Logger).to receive(:log)
        subject.new.perform(power_of_attorney.id)
      end
    end

    it 'skips running if flipper is disabled. Logs the skip.' do
      Flipper.disable(:claims_api_poa_v1_pdf_gen_fixup_job)
      expect(ClaimsApi::Logger).to receive(:log).with(
        described_class::LOG_TAG,
        detail: "Skipping pdf re-upload of POA #{power_of_attorney.id}. Flipper disabled."
      )
      expect(ClaimsApi::PowerOfAttorney).not_to receive(:find)
      subject.new.perform(power_of_attorney.id)
    end

    context 'when signature has prefix' do
      before do
        create(:veteran_representative, representative_id: '67890', poa_codes: ['ABC']).save!
        create(:veteran_organization, poa: 'ABC', name: 'Some org')
        power_of_attorney.update(form_data: power_of_attorney.form_data.deep_merge(
          {
            signatures: {
              veteran: bad_b64_image,
              representative: bad_b64_image
            }
          }
        ))
      end

      it 'DOES NOT set the status and store the error' do
        orig_status = power_of_attorney.status
        expect_any_instance_of(ClaimsApi::V1::PoaPdfConstructor::Organization).to receive(:construct)
          .and_raise(ClaimsApi::StampSignatureError)
        expect { subject.new.perform(power_of_attorney.id) }.to raise_error(ClaimsApi::StampSignatureError)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq(orig_status)
        expect(power_of_attorney.signature_errors).to be_empty
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

  context 'when the BD upload feature flag is enabled' do
    let(:errors) { 'some errors' }
    let(:pdf_path) { 'some/path' }
    let(:doc_type) { 'L075' }

    it 'calls the benefits document API upload instead of VBMS' do
      Flipper.enable(:lighthouse_claims_api_poa_use_bd)
      Flipper.disable(:claims_api_poa_uploads_bd_refactor)
      expect_any_instance_of(ClaimsApi::VBMSUploader).not_to receive(:upload_document)
      expect_any_instance_of(ClaimsApi::BD).to receive(:upload)

      subject.new.perform(power_of_attorney.id)
    end

    it 'calls the benefits document API upload_document instead of upload' do
      Flipper.enable(:lighthouse_claims_api_poa_use_bd)
      Flipper.enable(:claims_api_poa_uploads_bd_refactor)
      expect_any_instance_of(ClaimsApi::VBMSUploader).not_to receive(:upload_document)
      expect_any_instance_of(ClaimsApi::BD).not_to receive(:upload)
      expect_any_instance_of(ClaimsApi::BD).to receive(:upload_document)

      subject.new.perform(power_of_attorney.id)
    end

    it 'rescues errors from BD but DOES NOT sets the status to errored' do
      orig_status = power_of_attorney.status
      VCR.use_cassette('claims_api/bd/upload_error') do
        allow(ClaimsApi::BD.new).to receive(:upload).with(claim: power_of_attorney, pdf_path:, doc_type:)
                                                    .and_raise(Common::Exceptions::BackendServiceException.new(errors))

        # first log is for the BD upload error
        # second log is for the fixup job exception logging
        expect(ClaimsApi::Logger).to receive(:log).twice

        subject.new.perform(power_of_attorney.id)
      rescue
        power_of_attorney.reload
        expect(power_of_attorney.vbms_error_message).not_to eq(
          'BackendServiceException: {:status=>400, :detail=>nil, :code=>"VA900", :source=>nil}'
        )
        expect(power_of_attorney.status).to eq(orig_status)
      end
    end
  end
end
