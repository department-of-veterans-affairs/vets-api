# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/models/form_engine/employment_history'

RSpec.describe FormEngine::EmploymentHistory do
  subject(:employment_history) { described_class.new(data) }

  let(:fixture_file) { 'vba_21_4140.json' }
  let(:fixture_path) do
    Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', fixture_file)
  end
  let(:data) { JSON.parse(fixture_path.read)['employers'][0] }

  shared_examples 'properly formatted date' do
    it { is_expected.to match(%r{\d{2}/\d{2}/\d{4}}) }
  end

  it 'sets the correct attributes' do
    expect(employment_history.hours_per_week).to eq data['hours_per_week']
    expect(employment_history.lost_time).to eq data['lost_time']
    expect(employment_history.type_of_work).to eq data['type_of_work']
  end

  describe '.date_ended' do
    subject { employment_history.date_ended }

    it_behaves_like 'properly formatted date'
  end

  describe '.date_started' do
    subject { employment_history.date_started }

    it_behaves_like 'properly formatted date'
  end

  describe '#highest_income' do
    subject { employment_history.highest_income }

    it { is_expected.to eq '$2,300.00' }
  end

  describe '#name_and_address' do
    subject(:name_and_address) { employment_history.name_and_address }

    it 'returns a multi-line string' do
      expect(name_and_address).to(
        eq(
          'Test Employer\\n1234 Executive Ave\\nMetropolis, CA 90210\\nUnited States of America'
        )
      )
    end
  end
end
