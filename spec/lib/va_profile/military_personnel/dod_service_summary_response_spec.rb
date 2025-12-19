# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/military_personnel/dod_service_summary_response'

describe VAProfile::MilitaryPersonnel::DodServiceSummaryResponse do
  let(:status) { 200 }
  let(:body) do
    {
      'profile' => {
        'military_person' => {
          'military_summary' => {
            'customer_type' => {
              'dod_service_summary' => {
                'dod_service_summary_code' => 'V',
                'calculation_model_version' => '1.0',
                'effective_start_date' => '2020-01-01'
              }
            }
          }
        }
      }
    }
  end
  let(:raw_response) { double('RawResponse', status:, body:) }

  describe '.from' do
    context 'when successful' do
      it 'creates a response with dod_service_summary' do
        response = described_class.from(raw_response)

        expect(response.status).to eq(200)
        expect(response.dod_service_summary).to be_a(VAProfile::Models::DodServiceSummary)
        expect(response.dod_service_summary.dod_service_summary_code).to eq('V')
        expect(response.dod_service_summary.calculation_model_version).to eq('1.0')
        expect(response.dod_service_summary.effective_start_date).to eq('2020-01-01')
      end
    end

    context 'when body is nil' do
      let(:body) { nil }

      it 'returns a response with nil dod_service_summary' do
        response = described_class.from(raw_response)

        expect(response.status).to eq(200)
        expect(response.dod_service_summary).to be_nil
      end
    end

    context 'when dod_service_summary data is missing' do
      let(:body) do
        {
          'profile' => {
            'military_person' => {
              'military_summary' => {}
            }
          }
        }
      end

      it 'returns a response with nil dod_service_summary' do
        response = described_class.from(raw_response)

        expect(response.status).to eq(200)
        expect(response.dod_service_summary).to be_nil
      end
    end

    context 'when raw_response is nil' do
      let(:raw_response) { nil }

      it 'handles nil gracefully' do
        response = described_class.from(raw_response)

        expect(response.status).to be_nil
        expect(response.dod_service_summary).to be_nil
      end
    end
  end

  describe '.get_dod_service_summary' do
    context 'when body contains dod_service_summary data' do
      it 'extracts and builds a DodServiceSummary model' do
        summary = described_class.get_dod_service_summary(body)

        expect(summary).to be_a(VAProfile::Models::DodServiceSummary)
        expect(summary.dod_service_summary_code).to eq('V')
        expect(summary.calculation_model_version).to eq('1.0')
        expect(summary.effective_start_date).to eq('2020-01-01')
      end
    end

    context 'when body is nil' do
      it 'returns nil' do
        summary = described_class.get_dod_service_summary(nil)

        expect(summary).to be_nil
      end
    end

    context 'when dod_service_summary data is missing' do
      let(:incomplete_body) do
        {
          'profile' => {
            'military_person' => {}
          }
        }
      end

      it 'returns nil' do
        summary = described_class.get_dod_service_summary(incomplete_body)

        expect(summary).to be_nil
      end
    end
  end
end
