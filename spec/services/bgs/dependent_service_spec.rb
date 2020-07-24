# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:claim) { double('claim') }
  let(:vet_info) do
    {
      'veteran_information' => {
        'birth_date' => '1809-02-12',
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
    it "makes call to get veteran's va file number" do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        response = BGS::DependentService.new(user)
        expect(response).to receive(:add_va_file_number_to_payload)
          .with({ veteran_contact_information: {} }).and_return(vet_info)

        response.submit_686c_form({ veteran_contact_information: {} }, claim)
      end
    end

    it 'fires PDF job' do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        expect(VBMS::SubmitDependentsPDFJob).to receive(:perform_async).with(claim.id, vet_info)

        BGS::DependentService.new(user).submit_686c_form({ veteran_contact_information: {} }, claim)
      end
    end
  end
end
