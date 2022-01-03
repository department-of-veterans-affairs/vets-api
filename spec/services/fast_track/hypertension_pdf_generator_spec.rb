# frozen_string_literal: true

require 'rails_helper'
# require 'prawn'
# require 'prawn/table'
require 'lighthouse/veterans_health/client'

RSpec.describe FastTrack::HypertensionPdfGenerator, :vcr do
  let(:client) do
    # Using specific test ICN below:
    Lighthouse::VeteransHealth::Client.new(2_000_163)
  end

  let(:bp_data) do
    client.get_resource('observations')
  end

  let(:parsed_bp_data) do
    # At least one of the bp readings must be from the last year
    original_first_bp_reading = bp_data.body['entry'].first
    original_first_bp_reading['resource']['issued'] = (Time.zone.today - 2.weeks).to_s

    FastTrack::HypertensionObservationData.new(bp_data).transform
  end

  let(:parsed_medications_data) do
    FastTrack::HypertensionMedicationRequestData.new(client.get_resource('medications')).transform
  end

  let(:patient_name) { { first: 'Cat', middle: 'Marie', last: 'Power', suffix: 'Jr.' } }

  let!(:pdf) do
    pdf = FastTrack::HypertensionPdfGenerator.new(patient_name, parsed_bp_data, parsed_medications_data).generate
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  describe '#generate', :vcr do
    it 'includes the veterans name' do
      expect(pdf).to include 'Cat Marie Power, Jr.'
    end

    it 'includes the veterans blood pressure readings' do
      expect(pdf).to include 'Blood pressure: 115.0/87.0 mm[Hg]'
    end

    it 'includes the veterans medications' do
      dosages = parsed_medications_data.map do |per|
        "Dosage instructions: #{per['dosageInstructions'].join('; ')}"
      end

      expect(pdf).to include(*dosages)
    end
  end
end
