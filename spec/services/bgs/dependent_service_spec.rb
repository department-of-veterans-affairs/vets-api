# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#submit_686c_form' do
    it "makes call to get veteran's va file number" do
      VCR.use_cassette('bgs/dependent_service/submit_686c_form') do
        response = BGS::DependentService.new(user)
        expect(response).to receive(:add_va_file_number_to_payload)
                              .with({:veteran_contact_information=>{}})

        response.submit_686c_form({veteran_contact_information: {}})
      end
    end
  end
end