# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/models/form_engine/employment_history'

RSpec.describe SimpleFormsApi::FormEngine::EmploymentHistory do
  subject(:employment_history) { described_class.new(data) }

  let(:fixture_file) { 'vba_21_4140.json' }
  let(:fixture_path) do
    Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', fixture_file)
  end
  let(:data) { JSON.parse(fixture_path.read)['employers'][0] }

  it 'sets the correct attributes' do
    expect(employment_history.date_ended).to eq data.dig('date_range', 'to')
    expect(employment_history.date_started).to eq data.dig('date_range', 'from')
    expect(employment_history.hours_per_week).to eq data['hours_per_week']
    expect(employment_history.lost_time).to eq data['lost_time']
    expect(employment_history.type_of_work).to eq data['type_of_work']
  end

  describe '#highest_income' do
    it 'returns a currency string'
  end

  describe '#name_and_address' do
    it 'returns a multi-line string'
  end
end
