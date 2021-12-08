# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'
require 'fast_track/disability_compensation_job'

RSpec.describe FastTrack::HypertensionMedicationRequestData, :vcr do
  subject { described_class }

  let(:response) do
    # Using specific test ICN below:
    client = Lighthouse::VeteransHealth::Client.new(2_000_163)
    client.get_resource('medications')
  end

  describe '#transform' do
    empty_response = OpenStruct.new
    empty_response.body = { 'entry' => [] }
    it 'returns the expected hash from an empty list' do
      expect(described_class.new(empty_response).transform)
        .to eq([])
    end

    it 'returns the expected hash from a single-entry list' do
      expect(described_class.new(response).transform).to match(
        [
          {
            'status' => 'active',
            'authoredOn' => '1995-02-06T02:15:52Z',
            'description' => 'Hydrochlorothiazide 6.25 MG',
            'notes' => ['Hydrochlorothiazide 6.25 MG'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.']
          },
          { 'status' => 'active',
            'authoredOn' => '1995-04-30T01:15:52Z',
            'description' => 'Loratadine 5 MG Chewable Tablet',
            'notes' => ['Loratadine 5 MG Chewable Tablet'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '1995-04-30T01:15:52Z',
            'description' => '0.3 ML EPINEPHrine 0.5 MG/ML Auto-Injector',
            'notes' => [
              '0.3 ML EPINEPHrine 0.5 MG/ML Auto-Injector'
            ],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '1998-02-12T02:15:52Z',
            'description' => '120 ACTUAT Fluticasone propionate 0.044 MG/ACTUAT Metered Dose Inhaler',
            'notes' => [
              '120 ACTUAT Fluticasone propionate 0.044 MG/ACTUAT Metered Dose Inhaler'
            ],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '1998-02-12T02:15:52Z',
            'description' => '200 ACTUAT Albuterol 0.09 MG/ACTUAT Metered Dose Inhaler',
            'notes' => ['200 ACTUAT Albuterol 0.09 MG/ACTUAT Metered Dose Inhaler'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '2009-03-25T01:15:52Z',
            'description' => 'Hydrocortisone 10 MG/ML ' \
                             'Topical Cream',
            'notes' => ['Hydrocortisone 10 MG/ML Topical Cream'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] },
          { 'status' => 'active',
            'authoredOn' => '2012-08-18T06:15:52Z',
            'description' => 'predniSONE 5 MG Oral Tablet',
            'notes' => ['predniSONE 5 MG Oral Tablet'],
            'dosageInstructions' => [
              '1 dose(s) 1 time(s) per 1 days', 'As directed by physician.'
            ] },
          { 'status' => 'active',
            'authoredOn' => '2013-04-15T01:15:52Z',
            'description' => 'Hydrochlorothiazide 25 MG',
            'notes' => ['Hydrochlorothiazide 25 MG'],
            'dosageInstructions' => ['Once per day.', 'As directed by physician.'] }
        ]
      )
    end
  end
end
