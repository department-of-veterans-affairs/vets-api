# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentV2Service do
  let(:user) { create(:evss_user, :loa3, birth_date:, ssn: '796043735') }
  let(:user2) { create(:evss_user, :loa3, participant_id: nil, birth_date:, ssn: '796043735') }
  let(:birth_date) { '1809-02-12' }
  let(:claim) { double('claim') }
  let(:vet_info) do
    {
      'veteran_information' => {
        'full_name' => {
          'first' => 'WESLEY', 'middle' => nil, 'last' => 'FORD'
        },
        'common_name' => user.common_name,
        'participant_id' => '600061742',
        'uuid' => user.uuid,
        'email' => user.email,
        'icn' => user.icn,
        'va_profile_email' => user.va_profile_email,
        'ssn' => '796043735',
        'va_file_number' => '796043735',
        'birth_date' => birth_date
      }
    }
  end
  let(:encrypted_vet_info) { KmsEncrypted::Box.new.encrypt(vet_info.to_json) }

  before do
    allow(claim).to receive(:id).and_return('1234')
    allow_any_instance_of(KmsEncrypted::Box).to receive(:encrypt).and_return(encrypted_vet_info)

    allow(Flipper).to receive(:enabled?).with(anything).and_call_original
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:dependents_claims_evidence_api_upload).and_return(false)
  end

  describe '#submit_686c_form' do
    before do
      allow(claim).to receive_messages(submittable_686?: true, submittable_674?: true)
    end

    it 'calls find_person_by_participant_id' do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        service = BGS::DependentV2Service.new(user)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id)
        allow(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync)

        service.submit_686c_form(claim)
      end
    end

    context 'enqueues SubmitForm686cJob and SubmitDependentsPdfJob' do
      it 'fires jobs correctly' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          service = BGS::DependentV2Service.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm686cV2Job).to receive(:perform_async).with(
            user.uuid, user.icn, claim.id,
            encrypted_vet_info
          )
          expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
            claim.id, encrypted_vet_info, true,
            true
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BGS returns an eight-digit file number' do
      it 'submits a PDF and enqueues the SubmitForm686cJob' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '12345678'
          service = BGS::DependentV2Service.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm686cV2Job).to receive(:perform_async).with(
            user.uuid, user.icn, claim.id,
            encrypted_vet_info
          )
          expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
            claim.id, encrypted_vet_info, true,
            true
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BGS returns valid file number with dashes' do
      it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)
        expect(BGS::SubmitForm686cV2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          encrypted_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, encrypted_vet_info,
          true, true
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BGS returns file number longer than nine digits' do
      it 'still submits a PDF and enqueues the SubmitForm686cJob' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567890'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)

        expect(BGS::SubmitForm686cV2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          enc_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, enc_vet_info,
          true, true
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BGS returns file number shorter than eight digits' do
      it 'still submits a PDF and enqueues the SubmitForm686cJob' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)

        expect(BGS::SubmitForm686cV2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          enc_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, enc_vet_info,
          true, true
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BGS returns nine-digit file number that does not match the veteran\'s SSN' do
      it 'still submits a PDF and enqueue the SubmitForm686cJob' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '123456789'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)

        expect(BGS::SubmitForm686cV2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          enc_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, enc_vet_info,
          true, true
        )
        service.submit_686c_form(claim)
      end
    end
  end

  describe '#get_dependents' do
    it 'returns dependents' do
      VCR.use_cassette('bgs/dependent_service/get_dependents') do
        response = BGS::DependentV2Service.new(user).get_dependents

        expect(response).to include(number_of_records: '6')
      end
    end

    it 'calls get_dependents' do
      VCR.use_cassette('bgs/dependent_service/get_dependents') do
        expect_any_instance_of(BGS::ClaimantWebService).to receive(:find_dependents_by_participant_id)
          .with(user.participant_id, user.ssn)

        BGS::DependentV2Service.new(user).get_dependents
      end
    end
  end

  describe '#submit_674_form' do
    before do
      allow(claim).to receive_messages(submittable_686?: false, submittable_674?: true)
    end

    it 'calls find_person_by_participant_id' do
      allow(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync)
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        service = BGS::DependentV2Service.new(user)
        allow_any_instance_of(BGS::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id)

        service.submit_686c_form(claim)
      end
    end

    context 'enqueues SubmitForm674Job and SubmitDependentsPdfJob' do
      it 'fires jobs correctly' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          service = BGS::DependentV2Service.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(
            user.uuid, user.icn, claim.id,
            encrypted_vet_info
          )
          expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
            claim.id, encrypted_vet_info, false,
            true
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BGS returns an eight-digit file number' do
      it 'submits a PDF and enqueues the SubmitForm674Job' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '12345678'
          service = BGS::DependentV2Service.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(
            user.uuid, user.icn, claim.id,
            encrypted_vet_info
          )
          expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
            claim.id, encrypted_vet_info, false,
            true
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BGS returns valid file number with dashes' do
      it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)
        expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          encrypted_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, encrypted_vet_info, false,
          true
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BGS returns file number longer than nine digits' do
      it 'still submits a PDF and enqueues the SubmitForm674Job' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567890'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)

        expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          enc_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, enc_vet_info, false,
          true
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BGS returns file number shorter than eight digits' do
      it 'still submits a PDF and enqueues the SubmitForm674Job' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)

        expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          enc_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, enc_vet_info, false,
          true
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BGS returns nine-digit file number that does not match the veteran\'s SSN' do
      it 'still submits a PDF and enqueues the SubmitForm674Job' do
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '123456789'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)
        service = BGS::DependentV2Service.new(user)
        expect(service).not_to receive(:log_exception_to_sentry)

        expect(BGS::SubmitForm674V2Job).to receive(:perform_async).with(
          user.uuid, user.icn, claim.id,
          enc_vet_info
        )
        expect(VBMS::SubmitDependentsPdfV2Job).to receive(:perform_sync).with(
          claim.id, enc_vet_info, false,
          true
        )
        service.submit_686c_form(claim)
      end
    end
  end
end
