# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/models/form_engine/employment_history'

RSpec.describe FormEngine::EmploymentHistory do
  subject(:employment_history) { described_class.new(data) }

  let(:data) do
    {
      'type_of_work' => 'Full-time',
      'hours_per_week' => '40',
      'lost_time_from_illness' => '13',
      'highest_gross_income_per_month' => 2300,
      'employment_dates' => {
        'from' => '2018-03-15',
        'to' => '2020-06-30'
      },
      'employer_name' => 'Test Employer',
      'employer_address' => {
        'country' => 'USA',
        'street' => '1234 Executive Ave',
        'city' => 'Metropolis',
        'state' => 'CA',
        'postal_code' => '90210'
      }
    }
  end

  describe '#date_started' do
    subject { employment_history.date_started }

    it 'formats the date correctly' do
      expect(subject).to eq '03/15/2018'
    end
  end

  describe '#date_ended' do
    subject { employment_history.date_ended }

    it 'formats the date correctly' do
      expect(subject).to eq '06/30/2020'
    end
  end

  describe '#highest_income' do
    subject { employment_history.highest_income }

    it 'formats as currency' do
      expect(subject).to eq '$2,300.00'
    end
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
