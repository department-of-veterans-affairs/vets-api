# frozen_string_literal: true

require 'rails_helper'
RSpec.describe BGS::DependentService do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:dependent_service) { BGS::DependentService.new(user) }
  let(:params) do
    delete_me_root = Rails.root.to_s
    delete_me_payload_file = File.read("#{delete_me_root}/spec/services/bgs/support/possible_payload_snake_case.json")
    JSON.parse(delete_me_payload_file)
  end

  it 'returns a hash with proc information' do
    VCR.use_cassette('bgs/dependent_service/modify_dependents') do
      modify_dependents = dependent_service.modify_dependents(params)

      expect(modify_dependents).to include(:jrn_dt, :jrn_lctn_id, :jrn_obj_id, :jrn_status_type_cd, :jrn_user_id, :vnp_proc_id)
    end
  end

  # it 'creates a VnpVeteran' do
  #   VCR.use_cassette('bgs/dependent_service/modify_dependents') do
  #     not working
  #     expect_any_instance_of(BGS::VnpVeteran).to receive(:create)
  #
  #     dependent_service.modify_dependents(params)
  #   end
  # end
end