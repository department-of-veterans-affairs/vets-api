# frozen_string_literal: true

require 'rails_helper'
# require 'prawn'
# require 'prawn/table'
require 'lighthouse/veterans_health/client'

RSpec.describe RapidReadyForDecision::HypertensionPdfGenerator, :vcr do
  let(:client) do
    # Using specific test ICN below:
    Lighthouse::VeteransHealth::Client.new(2_000_163)
  end

  let(:bp_data) do
    client.list_resource('observations')
  end

  let(:parsed_bp_data) do
    # At least one of the bp readings must be from the last year
    original_first_bp_reading = bp_data.body['entry'].first
    original_first_bp_reading['resource']['issued'] = (DateTime.now - 2.weeks).iso8601

    RapidReadyForDecision::HypertensionObservationData.new(bp_data).transform
  end

  let(:parsed_medications_data) do
    RapidReadyForDecision::HypertensionMedicationRequestData.new(client.list_resource('medications')).transform
  end

  let(:patient_name) { { first: 'Cat', middle: 'Marie', last: 'Power', suffix: 'Jr.' } }

  let(:pdf_generator) do
    RapidReadyForDecision::HypertensionPdfGenerator.new(patient_name, parsed_bp_data, parsed_medications_data)
  end

  let!(:pdf) do
    PDF::Inspector::Text.analyze(pdf_generator.generate.render).strings
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
        next if per['dosageInstructions'].blank?

        "Dosage instructions: #{per['dosageInstructions'].join('; ')}"
      end.compact

      expect(pdf).to include(*dosages)
    end
  end
end
