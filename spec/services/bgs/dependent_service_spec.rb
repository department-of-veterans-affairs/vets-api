# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3, birth_date: birth_date) }
  let(:birth_date) { '1809-02-12' }
  let(:claim) { double('claim') }
  let(:vet_info) do
    {
      'veteran_information' => {
        'birth_date' => birth_date,
        'full_name' => {
          'first' => 'WESLEY', 'last' => 'FORD', 'middle' => nil
        },
        'ssn' => '796043735',
        'va_file_number' => '796043735'
      }
    }
  end

  before { allow(claim).to receive(:id).and_return('1234') }

  describe '#submit_686c_form' do
    it 'formats vet info using VetInfo class' do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        service = BGS::DependentService.new(user)
        allow(claim).to receive(:submittable_686?)
        allow(claim).to receive(:submittable_674?)

        expect(VetInfo).to receive(:new).with(user, a_hash_including(file_nbr: '796043735'))

        service.submit_686c_form(claim)
      end
    end

    it 'calls find_person_by_participant_id' do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        service = BGS::DependentService.new(user)
        expect_any_instance_of(BGS::PersonWebService).to receive(:find_person_by_ptcpnt_id)

        service.submit_686c_form(claim)
      end
    end

    context 'enqueues SubmitForm686cJob and SubmitDependentsPdfJob' do
      before do
        allow(claim).to receive(:submittable_686?).and_return(true)
        allow(claim).to receive(:submittable_674?).and_return(true)
      end

      it 'fires jobs correctly' do
        VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
          service = BGS::DependentService.new(user)
          expect(BGS::SubmitForm686cJob).to receive(:perform_async).with(user.uuid, claim.id, vet_info)
          expect(VBMS::SubmitDependentsPdfJob).to receive(:perform_async).with(claim.id, vet_info, true, true)
          service.submit_686c_form(claim)
        end
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
end
