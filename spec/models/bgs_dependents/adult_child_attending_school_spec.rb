# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::AdultChildAttendingSchool do
  let(:all_flows_payload) do
    payload = File.read("#{fixtures_path}/all_flows_payload.json")
    JSON.parse(payload)
  end

  describe '#format_info' do
    it 'formats info' do
      dependent_application = all_flows_payload['dependent_application']
      described_class.new(dependent_application)
    end
  end
end
