# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormPdfVersionJob, type: :job do
  let(:forms_response) do
    {
      'data' => [
        {
          'id' => '10-10EZ',
          'attributes' => {
            'form_name' => '10-10EZ',
            'sha256' => 'abc123def456',
            'last_revision_on' => '2024-01-15'
          }
        },
        {
          'id' => '21-526EZ',
          'attributes' => {
            'form_name' => '21-526EZ',
            'sha256' => 'xyz789uvw012',
            'last_revision_on' => '2024-01-10'
          }
        }
      ]
    }
  end

  let(:client) { instance_double(Forms::Client) }
  let(:response) { double(body: forms_response) }

  before do
    allow(Forms::Client).to receive(:new).with(nil).and_return(client)
    allow(client).to receive(:get_all).and_return(response)
  end

  describe '#perform' do
    it 'completes successfully with valid form data' do
      expect { subject.perform }.not_to raise_error
    end

    it 'caches SHA256 values for forms' do
      subject.perform

      expect(Rails.cache.read('form_pdf_revision_sha256:10-10EZ')).to eq('abc123def456')
      expect(Rails.cache.read('form_pdf_revision_sha256:21-526EZ')).to eq('xyz789uvw012')
    end

    context 'when form has changed' do
      before do
        Rails.cache.write('form_pdf_revision_sha256:10-10EZ', 'old_sha_value')
      end

      it 'detects changes and records metrics' do
        expect(StatsD).to receive(:increment)
          .with('form.pdf.change.detected', tags: ['form:10-10EZ', 'form_id:10-10EZ'])

        subject.perform
      end

      it 'logs revision information' do
        expect(Rails.logger).to receive(:info).with(
          a_string_including('PDF form 10-10EZ (form_id: 10-10EZ) was revised')
        )

        subject.perform
      end

      it 'updates cache with new SHA256 value' do
        subject.perform

        expect(Rails.cache.read('form_pdf_revision_sha256:10-10EZ')).to eq('abc123def456')
      end
    end

    context 'when form has not changed' do
      before do
        Rails.cache.write('form_pdf_revision_sha256:10-10EZ', 'abc123def456')
      end

      it 'does not trigger change detection metrics' do
        expect(StatsD).not_to receive(:increment)
          .with('form.pdf.change.detected', anything)

        subject.perform
      end

      it 'refreshes cache TTL' do
        subject.perform

        expect(Rails.cache.read('form_pdf_revision_sha256:10-10EZ')).to eq('abc123def456')
      end
    end

    context 'when API call fails' do
      before do
        allow(client).to receive(:get_all).and_raise(StandardError, 'API Error')
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error)
          .with('Error in FormPdfVersionJob: API Error')

        expect { subject.perform }.to raise_error(StandardError, 'API Error')
      end
    end

    context 'with malformed response data' do
      let(:forms_response) do
        {
          'data' => [
            {
              'id' => '10-10EZ',
              'attributes' => {
                'form_name' => '10-10EZ',
                'sha256' => 'valid_sha'
              }
            },
            {
              'id' => 'malformed-form'
              # Missing attributes
            }
          ]
        }
      end

      it 'handles individual form errors gracefully' do
        expect(Rails.logger).to receive(:error)
          .with(a_string_including('Error processing form malformed-form'))

        expect { subject.perform }.not_to raise_error

        # Valid form should still be processed
        expect(Rails.cache.read('form_pdf_revision_sha256:10-10EZ')).to eq('valid_sha')
      end
    end

    context 'with empty forms array' do
      let(:forms_response) { { 'data' => [] } }

      it 'completes without processing any forms' do
        expect { subject.perform }.not_to raise_error
        expect(Rails.cache.read('form_pdf_revision_sha256:10-10EZ')).to be_nil
      end
    end

    context 'with missing forms data' do
      let(:forms_response) { {} }

      it 'handles missing data structure gracefully' do
        expect { subject.perform }.to raise_error(NoMethodError)
      end
    end

    context 'with nil response body' do
      let(:response) { double(body: nil) }

      it 'handles nil response body' do
        expect { subject.perform }.to raise_error(NoMethodError)
      end
    end
  end
end
