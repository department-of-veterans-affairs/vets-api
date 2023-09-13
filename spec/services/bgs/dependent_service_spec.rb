# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3, birth_date:) }
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

  before { allow(claim).to receive(:id).and_return('1234') }

  context 'The flipper is turned on' do
    before do
      Flipper.enable(:dependents_submit_674_independently)
    end

    describe '#submit_686c_form' do
      before do
        allow(claim).to receive(:submittable_686?).and_return(true)
        allow(claim).to receive(:submittable_674?).and_return(true)
      end

      it 'calls find_person_by_participant_id' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          service = BGS::DependentService.new(user)
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id)

          service.submit_686c_form(claim)
        end
      end

      context 'enqueues SubmitForm686cJob and SubmitDependentsPdfJob' do
        it 'fires jobs correctly' do
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            service = BGS::DependentService.new(user)
            expect(service).not_to receive(:log_exception_to_sentry)
            expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
            expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
            service.submit_686c_form(claim)
          end
        end
      end

      context 'BGS returns an eight-digit file number' do
        it 'submits a PDF and enqueues the SubmitForm686cJob' do
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
            vet_info['veteran_information']['va_file_number'] = '12345678'
            service = BGS::DependentService.new(user)
            expect(service).not_to receive(:log_exception_to_sentry)
            expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
            expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
            service.submit_686c_form(claim)
          end
        end
      end

      context 'BGS returns valid file number with dashes' do
        it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength
          service = BGS::DependentService.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns file number longer than nine digits' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '1234567890'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c/674 submission: BGS file_nbr has invalid format! (XXXXXXXXXX)')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm686cJob).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns file number shorter than eight digits' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '1234567'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c/674 submission: BGS file_nbr has invalid format! (XXXXXXX)')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm686cJob).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns nine-digit file number that does not match the veteran\'s SSN' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '123456789'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c/674 submission: VA.gov SSN does not match BGS file_nbr!')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm686cJob).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end
    end

    describe '#get_dependents' do
      it 'returns dependents' do
        VCR.use_cassette('bgs/dependent_service/get_dependents') do
          response = BGS::DependentService.new(user).get_dependents

          expect(response).to include(number_of_records: '6')
        end
      end

      it 'calls get_dependents' do
        VCR.use_cassette('bgs/dependent_service/get_dependents') do
          expect_any_instance_of(BGS::ClaimantWebService).to receive(:find_dependents_by_participant_id)
            .with(user.participant_id, user.ssn)

          BGS::DependentService.new(user).get_dependents
        end
      end
    end

    describe '#submit_674_form' do
      before do
        allow(claim).to receive(:submittable_686?).and_return(false)
        allow(claim).to receive(:submittable_674?).and_return(true)
      end

      it 'calls find_person_by_participant_id' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          service = BGS::DependentService.new(user)
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id)

          service.submit_686c_form(claim)
        end
      end

      context 'enqueues SubmitForm674Job and SubmitDependentsPdfJob' do
        it 'fires jobs correctly' do
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            service = BGS::DependentService.new(user)
            expect(service).not_to receive(:log_exception_to_sentry)
            expect(BGS::SubmitForm674Job).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
            expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, false, true)
            service.submit_686c_form(claim)
          end
        end
      end

      context 'BGS returns an eight-digit file number' do
        it 'submits a PDF and enqueues the SubmitForm674Job' do
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
            vet_info['veteran_information']['va_file_number'] = '12345678'
            service = BGS::DependentService.new(user)
            expect(service).not_to receive(:log_exception_to_sentry)
            expect(BGS::SubmitForm674Job).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
            expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, false, true)
            service.submit_686c_form(claim)
          end
        end
      end

      context 'BGS returns valid file number with dashes' do
        it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength
          service = BGS::DependentService.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm674Job).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, false, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns file number longer than nine digits' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm674Job' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '1234567890'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c/674 submission: BGS file_nbr has invalid format! (XXXXXXXXXX)')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm674Job).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, false, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns file number shorter than eight digits' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm674Job' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '1234567'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c/674 submission: BGS file_nbr has invalid format! (XXXXXXX)')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm674Job).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, false, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns nine-digit file number that does not match the veteran\'s SSN' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm674Job' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '123456789'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c/674 submission: VA.gov SSN does not match BGS file_nbr!')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm674Job).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, false, true)
          service.submit_686c_form(claim)
        end
      end
    end
  end

  context 'The flipper is turned off' do
    before do
      Flipper.disable(:dependents_submit_674_independently)
    end

    describe '#submit_686c_form' do
      before do
        allow(claim).to receive(:submittable_686?).and_return(true)
        allow(claim).to receive(:submittable_674?).and_return(true)
      end

      it 'calls find_person_by_participant_id' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          service = BGS::DependentService.new(user)
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id)

          service.submit_686c_form(claim)
        end
      end

      context 'enqueues SubmitForm686cJob and SubmitDependentsPdfJob' do
        it 'fires jobs correctly' do
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            service = BGS::DependentService.new(user)
            expect(service).not_to receive(:log_exception_to_sentry)
            expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
            expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
            service.submit_686c_form(claim)
          end
        end
      end

      context 'BGS returns an eight-digit file number' do
        it 'submits a PDF and enqueues the SubmitForm686cJob' do
          VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
            expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '12345678' }) # rubocop:disable Layout/LineLength
            vet_info['veteran_information']['va_file_number'] = '12345678'
            service = BGS::DependentService.new(user)
            expect(service).not_to receive(:log_exception_to_sentry)
            expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
            expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
            service.submit_686c_form(claim)
          end
        end
      end

      context 'BGS returns valid file number with dashes' do
        it 'strips out the dashes before enqueuing the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '796-04-3735' }) # rubocop:disable Layout/LineLength
          service = BGS::DependentService.new(user)
          expect(service).not_to receive(:log_exception_to_sentry)
          expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, user.icn, claim.id, vet_info)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns file number longer than nine digits' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567890' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '1234567890'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c submission: BGS file_nbr has invalid format! (XXXXXXXXXX)')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm686cJob).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns file number shorter than eight digits' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '1234567' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '1234567'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c submission: BGS file_nbr has invalid format! (XXXXXXX)')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm686cJob).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end

      context 'BGS returns nine-digit file number that does not match the veteran\'s SSN' do
        it 'still submits a PDF, but raises an error and does not enqueue the SubmitForm686cJob' do
          expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id).and_return({ file_nbr: '123456789' }) # rubocop:disable Layout/LineLength
          vet_info['veteran_information']['va_file_number'] = '123456789'
          service = BGS::DependentService.new(user)
          expect(service).to receive(:log_exception_to_sentry).with(
            an_instance_of(RuntimeError).and(having_attributes(message: 'Aborting Form 686c submission: VA.gov SSN does not match BGS file_nbr!')), # rubocop:disable Layout/LineLength
            { icn: user.icn, uuid: user.uuid },
            anything
          )
          expect(BGS::SubmitForm686cJob).not_to receive(:perform_async)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
      end
    end
  end
end
