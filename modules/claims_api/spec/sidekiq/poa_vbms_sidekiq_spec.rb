# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/poa_vbms_sidekiq'
require 'bgs_service/person_web_service'

RSpec.describe ClaimsApi::PoaVbmsSidekiq, vcr: 'bgs/person_web_service/find_by_ssn' do
  let(:dummy_class) { Class.new { extend ClaimsApi::PoaVbmsSidekiq } }

  before do
    Sidekiq::Job.clear_all
    allow_any_instance_of(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return false
    allow_any_instance_of(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_poa_use_bd).and_return false
  end

  describe 'upload_to_vbms' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    context 'when upload is successful' do
      it 'updates the Power Of Attorney record' do
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '123456789' })
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload!).and_return(
          {
            vbms_new_document_version_ref_id: 'some value',
            vbms_document_series_ref_id: 'some value'
          }
        )

        dummy_class.upload_to_vbms(power_of_attorney, '/some/random/path')
        power_of_attorney.reload

        expect(power_of_attorney.status).to eq(ClaimsApi::PowerOfAttorney::UPLOADED)
        expect(power_of_attorney.vbms_new_document_version_ref_id).to eq('some value')
        expect(power_of_attorney.vbms_document_series_ref_id).to eq('some value')
      end
    end

    context 'error occurs while retrieving Veteran file number from BGS' do
      it "raises a 'FailedDependency' exception and logs to Sentry" do
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_raise(
          BGS::ShareError.new('HelloWorld')
        )
        expect(dummy_class).to receive(:log_exception_to_sentry)

        expect { dummy_class.upload_to_vbms(power_of_attorney, '/some/random/path') }.to raise_error(
          Common::Exceptions::FailedDependency
        )
      end
    end

    describe 'when the claims_api_use_person_web_service flipper is on' do
      let(:person_web_service) { instance_double(ClaimsApi::PersonWebService) }

      before do
        allow(Flipper).to receive(:enabled?).with(:claims_api_use_person_web_service).and_return true
        allow(ClaimsApi::PersonWebService).to receive(:new).with(external_uid: anything,
                                                                 external_key: anything)
                                                           .and_return(person_web_service)
        allow(person_web_service).to receive(:find_by_ssn).and_return({ file_nbr: '796111863' })
      end

      it 'calls local bgs services instead of bgs-ext' do
        allow_any_instance_of(ClaimsApi::VBMSUploader).to receive(:upload!).and_return(
          {
            vbms_new_document_version_ref_id: 'some value',
            vbms_document_series_ref_id: 'some value'
          }
        )

        dummy_class.upload_to_vbms(power_of_attorney, '/some/random/path')
        expect(person_web_service).to have_received(:find_by_ssn)
      end
    end
  end
end
