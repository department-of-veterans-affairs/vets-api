# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/uploader'

RSpec.describe BEP::DependentService do
  let(:user) { create(:evss_user, :loa3, birth_date:, ssn: '796043735') }
  let(:user2) { create(:evss_user, :loa3, participant_id: nil, birth_date:, ssn: '796043735') }
  let(:birth_date) { '1809-02-12' }
  let(:claim) { build(:dependency_claim) }
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
  let(:service) { BEP::DependentService.new(user) }
  let(:single_dependent_response) do
    {
      number_of_records: '1',
      persons: { award_indicator: 'Y',
                 date_of_birth: '07/09/2024',
                 email_address: nil,
                 first_name: 'TESTER',
                 gender: 'M',
                 last_name: 'TEST',
                 proof_of_dependency: 'N',
                 participant_id: '123456789',
                 related_to_vet: 'Y',
                 relationship: 'Child',
                 ssn: '123456789',
                 veteran_indicator: 'N' },
      return_code: 'SHAR 9999',
      return_message: 'Records found'
    }
  end

  before do
    # TODO: Add back user_account_id once the DB migration is done
    allow(claim).to receive_messages(id: '1234', use_v2: false,
                                     submittable_686?: false, submittable_674?: true, add_veteran_info: true,
                                     valid?: true, persistent_attachments: [], form_id: '686C-674', document_type: 148)
    allow_any_instance_of(KmsEncrypted::Box).to receive(:encrypt).and_return(encrypted_vet_info)
  end

  describe '#submit_686c_form' do
    before do
      allow(claim).to receive_messages(submittable_686?: true, submittable_674?: true)
      allow(service).to receive(:submit_pdf_job)
    end

    it 'calls find_person_by_participant_id' do
      VCR.use_cassette('bep/dependent_service/submit_686c_form') do
        allow_any_instance_of(BEP::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id)

        service.submit_686c_form(claim)
      end
    end

    context 'enqueues SubmitForm686cJob' do
      it 'fires jobs correctly' do
        VCR.use_cassette('bep/dependent_service/submit_686c_form') do
          expect(BEP::SubmitForm686cJob).to receive(:perform_async).with(
            user.uuid, claim.id,
            encrypted_vet_info
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BEP returns an eight-digit file number' do
      it 'submits a PDF and enqueues the SubmitForm686cJob' do
        VCR.use_cassette('bep/dependent_service/submit_686c_form') do
          expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '12345678'
          expect(BEP::SubmitForm686cJob).to receive(:perform_async).with(
            user.uuid, claim.id,
            encrypted_vet_info
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BEP returns valid file number with dashes' do
      it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength

        expect(BEP::SubmitForm686cJob).to receive(:perform_async).with(
          user.uuid, claim.id,
          encrypted_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BEP returns file number longer than nine digits' do
      it 'still submits a PDF and enqueues the SubmitForm686cJob' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567890'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)

        expect(BEP::SubmitForm686cJob).to receive(:perform_async).with(
          user.uuid, claim.id,
          enc_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BEP returns file number shorter than eight digits' do
      it 'still submits a PDF and enqueues the SubmitForm686cJob' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)

        expect(BEP::SubmitForm686cJob).to receive(:perform_async).with(
          user.uuid, claim.id,
          enc_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BEP returns nine-digit file number that does not match the veteran\'s SSN' do
      it 'still submits a PDF and enqueue the SubmitForm686cJob' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '123456789'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)

        expect(BEP::SubmitForm686cJob).to receive(:perform_async).with(
          user.uuid, claim.id,
          enc_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'on error' do
      let(:monitor) { instance_double(Dependents::Monitor) }
      let(:uploader) { double('uploader') }

      before do
        allow(Dependents::Monitor).to receive(:new).and_return(monitor).at_least(:once)
        allow(monitor).to receive(:track_event).at_least(:once)

        allow(ClaimsEvidenceApi::Uploader).to receive(:new).and_return(uploader)
      end

      it 'submits to backup job on pdf submission errors' do
        VCR.use_cassette('bep/dependent_service/submit_686c_form') do
          allow(service).to receive(:submit_pdf_job).and_call_original
          allow(uploader).to receive(:upload_evidence).and_raise(StandardError, 'Test error')

          expect(BEP::SubmitForm686cJob).not_to receive(:perform_async)
          expect(service).to receive(:submit_to_central_service)

          service.submit_686c_form(claim)
        end
      end

      it 'in case of other errors it logs the exception and raises a custom error' do
        VCR.use_cassette('bep/dependent_service/submit_686c_form') do
          allow(BEP::SubmitForm686cJob).to receive(:perform_async).and_raise(StandardError,
                                                                             'Test error')

          expect(monitor).to receive(:track_event)

          expect do
            service.submit_686c_form(claim)
          end.to raise_error(StandardError, 'Test error')
        end
      end
    end
  end

  describe '#get_dependents' do
    it 'returns dependents' do
      VCR.use_cassette('bep/dependent_service/get_dependents') do
        response = BEP::DependentService.new(user).get_dependents

        expect(response).to include(number_of_records: '6')
      end
    end

    it 'returns a valid response when empty array' do
      VCR.use_cassette('bep/dependent_service/get_dependents') do
        allow_any_instance_of(BEP::ClaimantWebService).to receive(:find_dependents_by_participant_id)
          .with(user.participant_id, user.ssn).and_return([])

        response = BEP::DependentService.new(user).get_dependents

        expect(response).to have_key(:persons)
      end
    end

    it 'handles a single dependent response' do
      allow_any_instance_of(BEP::ClaimantWebService).to receive(:find_dependents_by_participant_id)
        .with(user.participant_id, user.ssn).and_return(single_dependent_response.deep_dup)
      response = service.get_dependents

      expect(response).to include(persons: Array)
      expect(response[:persons].size).to eq(1)
      expect(response[:persons][0]).to eq(single_dependent_response[:persons])
    end
  end

  describe '#submit_674_form' do
    before do
      allow(claim).to receive_messages(submittable_686?: false, submittable_674?: true)
      allow(service).to receive(:submit_pdf_job)
    end

    it 'calls find_person_by_participant_id' do
      VCR.use_cassette('bep/dependent_service/submit_686c_form') do
        allow_any_instance_of(BEP::PersonWebService).to receive(:find_by_ssn).and_return({ file_nbr: '796043735' })
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id)

        service.submit_686c_form(claim)
      end
    end

    context 'enqueues SubmitForm674Job' do
      it 'fires jobs correctly' do
        VCR.use_cassette('bep/dependent_service/submit_686c_form') do
          expect(BEP::SubmitForm674Job).to receive(:perform_async).with(
            user.uuid, claim.id,
            encrypted_vet_info
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BEP returns an eight-digit file number' do
      it 'submits a PDF and enqueues the SubmitForm674Job' do
        VCR.use_cassette('bep/dependent_service/submit_686c_form') do
          expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '12345678'
          expect(BEP::SubmitForm674Job).to receive(:perform_async).with(
            user.uuid, claim.id,
            encrypted_vet_info
          )
          service.submit_686c_form(claim)
        end
      end
    end

    context 'BEP returns valid file number with dashes' do
      it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength

        expect(BEP::SubmitForm674Job).to receive(:perform_async).with(
          user.uuid, claim.id,
          encrypted_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BEP returns file number longer than nine digits' do
      it 'still submits a PDF and enqueues the SubmitForm674Job' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567890'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)

        expect(BEP::SubmitForm674Job).to receive(:perform_async).with(
          user.uuid, claim.id,
          enc_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BEP returns file number shorter than eight digits' do
      it 'still submits a PDF and enqueues the SubmitForm674Job' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '1234567'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)

        expect(BEP::SubmitForm674Job).to receive(:perform_async).with(
          user.uuid, claim.id,
          enc_vet_info
        )
        service.submit_686c_form(claim)
      end
    end

    context 'BEP returns nine-digit file number that does not match the veteran\'s SSN' do
      it 'still submits a PDF and enqueues the SubmitForm674Job' do
        expect_any_instance_of(BEP::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
        vet_info['veteran_information']['va_file_number'] = '123456789'
        enc_vet_info = KmsEncrypted::Box.new.encrypt(vet_info.to_json)

        expect(BEP::SubmitForm674Job).to receive(:perform_async).with(
          user.uuid, claim.id,
          enc_vet_info
        )
        service.submit_686c_form(claim)
      end
    end
  end

  context 'claims evidence enabled' do
    let(:pa) { build(:claim_evidence, id: 23) }
    let(:ssn) { '123456789' }
    let(:folder_identifier) { "VETERAN:SSN:#{ssn}" }
    let(:uploader) { ClaimsEvidenceApi::Uploader.new(folder_identifier) }
    let(:service) { BEP::DependentService.new(user) }
    let(:monitor) { Dependents::Monitor.new(claim.id) }
    let(:pdf_path) { 'path/to/pdf' }
    let(:stamper) { PDFUtilities::PDFStamper.new('TEST') }
    let(:stats_key) { BEP::DependentService::STATS_KEY }

    before do
      allow(SavedClaim::DependencyClaim).to receive(:find).and_return(claim)
      allow(claim).to receive_messages(submittable_686?: true, submittable_674?: true, process_pdf: pdf_path)

      allow(ClaimsEvidenceApi::Uploader).to receive(:new).with(folder_identifier).and_return(uploader)
      allow(PDFUtilities::PDFStamper).to receive(:new).and_return(stamper)
      allow(PdfFill::Filler).to receive(:fill_form).and_return(claim.form_id)

      service.instance_variable_set(:@ssn, ssn)
    end

    it 'submits evidence pdf via claims evidence uploader' do
      expect(Dependents::Monitor).to receive(:new).with(claim.id).and_return(monitor)
      expect(monitor).to receive(:track_event).with(
        'info', 'BEP::DependentService#submit_pdf_job called to begin ClaimsEvidenceApi::Uploader',
        "#{stats_key}.submit_pdf.begin"
      )
      expect(ClaimsEvidenceApi::Uploader).to receive(:new).with(folder_identifier).and_return(uploader)

      expect(uploader).to receive(:upload_evidence).with(claim.id, file_path: pdf_path, form_id: '686C-674',
                                                                   doctype: claim.document_type)
      expect(uploader).to receive(:upload_evidence).with(claim.id, file_path: pdf_path, form_id: '21-674',
                                                                   doctype: 142)

      expect(claim).to receive(:persistent_attachments).and_return([pa])
      expect(stamper).to receive(:run).and_return(pdf_path)
      expect(uploader).to receive(:upload_evidence).with(claim.id, pa.id, file_path: pdf_path, form_id: '21-674',
                                                                          doctype: pa.document_type)

      expect(monitor).to receive(:track_event).with(
        'info', "BEP::DependentService claims evidence upload of 686C-674 claim_id #{claim.id}",
        "#{stats_key}.claims_evidence.upload", tags: ['form_id:686C-674']
      )
      expect(monitor).to receive(:track_event).with(
        'info', "BEP::DependentService claims evidence upload of 21-674 claim_id #{claim.id}",
        "#{stats_key}.claims_evidence.upload", tags: ['form_id:21-674']
      )
      expect(monitor).to receive(:track_event).with('info', 'BEP::DependentService#submit_pdf_job completed',
                                                    "#{stats_key}.submit_pdf.completed")

      service.send(:submit_pdf_job, claim:)
    end
  end
end
