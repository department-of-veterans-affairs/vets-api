# frozen_string_literal: true

require 'rails_helper'
require 'bgs/value_objects/vnp_person_address_phone'

RSpec.describe BGS::StudentSchool do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:proc_id) { '3828510' }
  let(:vnp_participant_id) { '147512' }
  let(:payload) do
    root = Rails.root.to_s
    f = File.read("#{root}/spec/services/bgs/support/final_payload.rb")
    JSON.parse(f)
  end

  describe '#create' do
    it 'creates a child school and a child student' do
      VCR.use_cassette('bgs/student_school/create') do
        student_school = BGS::StudentSchool.new(
          proc_id: proc_id,
          vnp_participant_id: vnp_participant_id,
          payload: payload,
          user: user
        ).create

      end
    end
  end
end