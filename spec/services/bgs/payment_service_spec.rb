# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGS::PeopleService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#find_person_by_participant_id' do
    it 'returns a person hash given a participant_id' do
      VCR.use_cassette('bgs/payment_service/payment_history') do
        service = BGS::PaymentService.new(user)
        response = service.payment_history

        expect(response).to include(:file_nbr, :brthdy_dt, :last_nm)
      end
    end
  end
end