require 'rails_helper'

RSpec.describe Facilities::WebsiteUrlService do
  let(:user) { FactoryBot.create(:evss_user, :loa3) }

  describe '#find_person_by_ptcpnt_id' do
    it 'returns a person object given a participant_id' do
      VCR.use_cassette('bgs/people_service/person_data') do
        service = BGS::PeopleService.new
        response = service.find_person_by_ptcpnt_id(user)

        expect(response).to include(:file_nbr, :brthdy_dt, :last_nm)
      end
    end
  end
end