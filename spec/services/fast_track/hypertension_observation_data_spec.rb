# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'
require 'fast_track/disability_compensation_job'

RSpec.describe FastTrack::HypertensionObservationData, :vcr do
  subject { described_class }

  let(:response) do
    # Using specific test ICN below:
    client = Lighthouse::VeteransHealth::Client.new(2_000_163)
    client.get_resource('observations')
  end

  describe '#transform' do
    it 'returns the expected hash' do
      expect(described_class.new(response).transform)
        .to match(
          [
            {
              issued: '2009-03-23T01:15:52Z',
              practitioner: 'DR. THOMAS359 REYNOLDS206 PHD',
              organization: 'LYONS VA MEDICAL CENTER',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 115.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 87.0,
                'unit' => 'mm[Hg]'
              }
            },
            {
              issued: '2010-03-29T01:15:52Z',
              practitioner: 'DR. JANE460 DOE922 MD',
              organization: 'WASHINGTON VA MEDICAL CENTER',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 102.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 70.0,
                'unit' => 'mm[Hg]'
              }
            },
            {
              issued: '2011-04-04T01:15:52Z',
              organization: 'NEW AMSTERDAM CBOC',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 137.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 86.0,
                'unit' => 'mm[Hg]'
              }
            },
            {
              issued: '2012-04-09T01:15:52Z',
              organization: 'LYONS VA MEDICAL CENTER',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 124.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 80.0,
                'unit' => 'mm[Hg]'
              }
            },
            {
              issued: '2013-04-15T01:15:52Z',
              practitioner: 'DR. JOHN248 SMITH811 MD',
              organization: 'NEW AMSTERDAM CBOC',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 156.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 118.0,
                'unit' => 'mm[Hg]'
              }
            },
            {
              issued: '2014-04-21T01:15:52Z',
              practitioner: 'DR. JANE460 DOE922 MD',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 192.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 93.0,
                'unit' => 'mm[Hg]'
              }
            },
            {
              issued: '2017-04-24T01:15:52Z',
              practitioner: 'DR. JANE460 DOE922 MD',
              organization: 'WASHINGTON VA MEDICAL CENTER',
              systolic: {
                'code' => '8480-6',
                'display' => 'Systolic blood pressure',
                'value' => 153.0,
                'unit' => 'mm[Hg]'
              },
              diastolic: {
                'code' => '8462-4',
                'display' => 'Diastolic blood pressure',
                'value' => 99.0,
                'unit' => 'mm[Hg]'
              }
            }
          ]
        )
    end

    it 'returns the expected hash from an empty list' do
      empty_response = OpenStruct.new
      empty_response.body = { 'entry': [] }.with_indifferent_access
      expect(described_class.new(empty_response).transform)
        .to eq([])
    end

    it 'returns nil from missing component field' do
      empty_response = OpenStruct.new
      empty_response.body = { 'entry': [{ 'resource': {} }] }.with_indifferent_access
      expect(described_class.new(empty_response).transform).to eq([{ issued: nil }])
    end
  end
end
