# frozen_string_literal: true
require 'rails_helper'
RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:user, :loa3) }
  it 'provides the url when it knows about a station id and facility type' do
    VCR.use_cassette('bgs/vnp_proc/dependents') do
      service = BGS::DependentService.new(user)
      service.modify_dependents
    end
  end
end
