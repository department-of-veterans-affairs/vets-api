# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:params) do
    delete_me_root = Rails.root.to_s
    delete_me_payload_file = File.read("#{delete_me_root}/spec/services/bgs/support/possible_payload_snake_case.json")
    JSON.parse(delete_me_payload_file)
  end

  it 'provides the url when it knows about a station id and facility type' do
    VCR.use_cassette('bgs/modify_dependents') do
      binding.pry
      service = BGS::DependentService.new(user)
      service.modify_dependents(params)
    end
  end
end
