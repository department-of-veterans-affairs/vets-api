# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormPdfChangeDetectionJob, type: :job do
  let(:meta_data) { "[#{described_class.name}]" }

  let(:forms_response) do
    {
      'data' => [
        {
          'id' => '10-10EZ',
          'attributes' => {
            'form_name' => '10-10EZ',
            'sha256' => 'abc123def456',
            'last_revision_on' => '2024-01-15',
            'url' => 'some-url.com'
          }
        },
        {
          'id' => '21-526EZ',
          'attributes' => {
            'form_name' => '21-526EZ',
            'sha256' => 'xyz789uvw012',
            'last_revision_on' => '2024-01-10',
            'url' => 'some-other-url.com'
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

    @mock_cache = {}

    allow(Rails.cache).to receive(:read_multi) do |*keys|
      result = {}
      keys.each do |key|
        result[key] = @mock_cache[key] if @mock_cache.key?(key)
      end
      result
    end

    allow(Rails.cache).to receive(:write_multi) do |data, **_options|
      @mock_cache.merge!(data)
      true
    end
  end

  describe '#perform' do
    context ':form_pdf_change_detection disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_pdf_change_detection).and_return(false)
      end

      it 'does not run' do
        expect(Forms::Client).not_to receive(:new)
        expect(Rails.cache).not_to receive(:read_multi)
        expect(Rails.cache).not_to receive(:write_multi)
        expect(StatsD).not_to receive(:increment)

        expect(Rails.logger).not_to receive(:info).with(
          "#{meta_data} - Job started."
        )

        subject.perform
      end
    end

    context ':form_pdf_change_detection enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_pdf_change_detection).and_return(true)
      end

      it 'sets cache values without triggering change detection metrics on initial run' do
        expect(@mock_cache).to be_empty

        expect(StatsD).not_to receive(:increment)
          .with('form.pdf.change.detected', anything)

        expect(Rails.logger).not_to receive(:info)
          .with(a_string_including('was revised'))

        subject.perform

        expect(@mock_cache['form_pdf_revision_sha256:10-10EZ']).to eq('abc123def456')
        expect(@mock_cache['form_pdf_revision_sha256:21-526EZ']).to eq('xyz789uvw012')
      end

      it 'completes successfully with valid form data' do
        expect(Rails.logger).to receive(:info).with(
          "#{meta_data} - Job started."
        )
        expect(Rails.logger).to receive(:info).with(
          "#{meta_data} - Job finished successfully."
        )
        expect { subject.perform }.not_to raise_error
      end

      it 'uses batch operations to read and write cache' do
        expected_keys = [
          'form_pdf_revision_sha256:10-10EZ',
          'form_pdf_revision_sha256:21-526EZ'
        ]

        expect(Rails.cache).to receive(:read_multi).with(*expected_keys)

        expected_data = {
          'form_pdf_revision_sha256:10-10EZ' => 'abc123def456',
          'form_pdf_revision_sha256:21-526EZ' => 'xyz789uvw012'
        }

        expect(Rails.cache).to receive(:write_multi).with(expected_data, expires_in: 7.days.to_i)

        subject.perform
      end

      it 'caches SHA256 values for forms using batch write' do
        subject.perform

        expect(@mock_cache['form_pdf_revision_sha256:10-10EZ']).to eq('abc123def456')
        expect(@mock_cache['form_pdf_revision_sha256:21-526EZ']).to eq('xyz789uvw012')
      end

      context 'when form has changed' do
        before do
          @mock_cache['form_pdf_revision_sha256:10-10EZ'] = 'old_sha_value'
        end

        it 'detects changes using batch read and records metrics' do
          expect(StatsD).to receive(:increment)
            .with('form.pdf.change.detected', tags: ['form:10-10EZ', 'form_id:10-10EZ'])

          subject.perform
        end

        it 'logs revision information' do
          form = forms_response['data'][0]
          attributes = form['attributes']
          expect(Rails.logger).to receive(:info).with(
            "#{meta_data} - Job started."
          )

          expect(Rails.logger).to receive(:info).with(
            "#{meta_data} - Job finished successfully."
          )

          expect(Rails.logger).to receive(:info).with(
            a_string_including(
              "#{meta_data} - PDF form #{attributes['form_name']} (form_id: #{form['id']}) was revised. " \
              "Last revised on date: #{attributes['last_revision_on']}. " \
              "URL: #{attributes['url']}"
            )
          )

          subject.perform
        end

        it 'updates cache with new SHA256 value using batch write' do
          subject.perform

          expect(@mock_cache['form_pdf_revision_sha256:10-10EZ']).to eq('abc123def456')
        end
      end

      context 'when form has not changed' do
        before do
          @mock_cache['form_pdf_revision_sha256:10-10EZ'] = 'abc123def456'
        end

        it 'does not trigger change detection metrics' do
          expect(StatsD).not_to receive(:increment)
            .with('form.pdf.change.detected', anything)

          subject.perform
        end

        it 'still updates cache using batch write to refresh TTL' do
          expect(Rails.cache).to receive(:write_multi)

          subject.perform

          expect(@mock_cache['form_pdf_revision_sha256:10-10EZ']).to eq('abc123def456')
        end
      end

      context 'when API call fails' do
        before do
          allow(client).to receive(:get_all).and_raise(StandardError, 'API Error')
        end

        it 'logs the error and re-raises' do
          expect(Rails.logger).to receive(:info).with(
            "#{meta_data} - Job started."
          )
          expect(Rails.logger).not_to receive(:info).with(
            "#{meta_data} - Job finished successfully."
          )
          expect(Rails.logger).to receive(:error)
            .with("#{meta_data} - Job raised an error: API Error")

          expect { subject.perform }.to raise_error(StandardError, 'API Error')
        end

        it 'does not perform any cache operations' do
          expect(Rails.cache).not_to receive(:read_multi)
          expect(Rails.cache).not_to receive(:write_multi)

          expect { subject.perform }.to raise_error(StandardError, 'API Error')
        end
      end

      context 'when form processing raises an exception despite valid id' do
        let(:forms_response) do
          {
            'data' => [
              {
                'id' => '10-10EZ',
                'attributes' => {
                  'form_name' => '10-10EZ',
                  'sha256' => 'abc123def456'
                }
              }
            ]
          }
        end

        before do
          allow_any_instance_of(Hash).to receive(:dig).and_call_original
          allow_any_instance_of(Hash).to receive(:dig).with('attributes', 'sha256') do |form|
            if form['id'] == '10-10EZ'
              raise StandardError, 'Simulated processing error'
            else
              form.dig('attributes', 'sha256')
            end
          end
        end

        it 'catches the exception and logs the error' do
          expect(Rails.logger).to receive(:error)
            .with("#{meta_data} - Error processing form 10-10EZ: Simulated processing error")

          expect { subject.perform }.not_to raise_error
        end
      end

      context 'with empty forms array' do
        let(:forms_response) { { 'data' => [] } }

        it 'completes without performing cache operations' do
          expect(Rails.cache).to receive(:read_multi).with(no_args).and_return({})
          expect(Rails.cache).not_to receive(:write_multi)

          expect { subject.perform }.not_to raise_error
        end
      end

      context 'with missing forms data' do
        let(:forms_response) { {} }

        it 'handles missing data structure gracefully' do
          expect { subject.perform }.to raise_error(NoMethodError)
        end
      end
    end
  end
end
