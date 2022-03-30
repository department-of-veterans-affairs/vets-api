# frozen_string_literal: true

require 'rails_helper'
# require 'prawn'
# require 'prawn/table'
require 'lighthouse/veterans_health/client'

RSpec.describe RapidReadyForDecision::FastTrackPdfGenerator, :vcr do
  subject { PDF::Inspector::Text.analyze(compiled_pdf.render).strings }

  let(:compiled_pdf) { pdf_generator.generate }

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
    original_first_bp_reading['resource']['effectiveDateTime'] = (DateTime.now - 2.weeks).iso8601

    RapidReadyForDecision::LighthouseObservationData.new(bp_data).transform
  end

  let(:parsed_medications_data) do
    RapidReadyForDecision::LighthouseMedicationRequestData.new(client.list_resource('medication_requests')).transform
  end

  let(:patient_name) do
    { first: 'Cat', middle: 'Marie', last: 'Power', suffix: 'Jr.', birthdate: '10-10-1968' }
  end

  let(:pdf_generator) do
    RapidReadyForDecision::FastTrackPdfGenerator.new(patient_name, parsed_bp_data, parsed_medications_data)
  end

  describe '#generate', :vcr do
    it 'includes the veterans name' do
      expect(subject).to include 'Cat Marie Power, Jr.'
    end

    it 'includes the veterans birthdate' do
      expect(subject).to include 'DOB: 10-10-1968'
    end

    it 'includes the veterans blood pressure readings' do
      expect(subject).to include 'Blood pressure: 115/87'
    end

    it 'includes the veterans medications' do
      dosages = parsed_medications_data.map do |per|
        next if per['dosageInstructions'].blank?

        "Dosage instructions: #{per['dosageInstructions'].join('; ')}"
      end.compact

      expect(subject).to include(*dosages)
    end

    context 'when no medications are present' do
      let(:parsed_medications_data) { [] }

      it 'shows message when no medications are present' do
        expect(subject).to include('No active medications were found in the last year')
      end

      it 'shows the active prescriptions header even if no meds present' do
        expect(subject).to include('Active Prescriptions')
      end
    end
  end
end
