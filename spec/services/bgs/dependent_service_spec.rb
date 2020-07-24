# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }
  let(:claim) { double('claim') }
  before(:each) { allow(claim).to  receive(:id).and_return('1234') }

  describe '#submit_686c_form' do
    it "makes call to get veteran's va file number" do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        response = BGS::DependentService.new(user)
        expect(response).to receive(:add_va_file_number_to_payload)
                              .with({:veteran_contact_information=>{}})

        response.submit_686c_form({veteran_contact_information: {}}, claim)
      end
    end

    it "fires PDF job" do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        response = BGS::DependentService.new(user)
        # binding.pry
        # expect(VBMS::SubmitDependentsPDFJob).to receive(:perform_async).with(claim.id, 'xyz')

        response.submit_686c_form({veteran_contact_information: {}}, claim)
        binding.pry
        expect(response).to be_truthy
      end
    end
  end
end
