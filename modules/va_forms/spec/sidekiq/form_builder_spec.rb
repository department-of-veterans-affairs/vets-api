# frozen_string_literal: true

require 'rails_helper'
require VAForms::Engine.root.join('spec', 'rails_helper.rb')

# rubocop:disable Layout/LineLength
RSpec.describe VAForms::FormBuilder, type: :job do
  subject { described_class }

  let(:form_builder) { described_class.new }
  let(:slack_messenger) { instance_double(VAForms::Slack::Messenger) }

  let(:default_form_data) { JSON.parse(File.read(VAForms::Engine.root.join('spec', 'fixtures', 'gql_form.json'))) }
  let(:invalid_url_form_data) { JSON.parse(File.read(VAForms::Engine.root.join('spec', 'fixtures', 'gql_form_invalid_url.json'))) }
  let(:deleted_form_data) { JSON.parse(File.read(VAForms::Engine.root.join('spec', 'fixtures', 'gql_form_deleted.json'))) }

  let(:valid_pdf_cassette) { 'va_forms/valid_pdf' }
  let(:not_found_pdf_cassette) { 'va_forms/pdf_not_found' }
  let(:server_error_pdf_cassette) { 'va_forms/pdf_internal_server_error' }

  let(:form_fetch_error_message) { 'The form could not be fetched from the url provided. Response code: 500' }

  before do
    Sidekiq::Job.clear_all
    allow(Rails.logger).to receive(:error)
    allow(VAForms::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    let(:form_name) { '21-0966' }
    let(:url) { 'https://www.vba.va.gov/pubs/forms/VBA-21-0966-ARE.pdf' }
    let(:valid_sha256) { 'b1ee32f44d7c17871e4aba19101ba6d55742674e6e1627498d618a356ea6bc78' }
    let(:sha256) { valid_sha256 }
    let(:title) { form_data['fieldVaFormName'] }
    let(:row_id) { form_data['fieldVaFormRowId'] }
    let(:valid_pdf) { true }
    let(:form_data) { default_form_data }
    let(:enable_notifications) { true }
    let(:result) do
      form = VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf:, row_id:)
      with_settings(Settings.va_forms.slack, enabled: enable_notifications) do
        VCR.use_cassette(valid_pdf_cassette) do
          form_builder.perform(form_data)
        end
      end
      form.reload
    end

    context 'when the form url returns a successful response' do
      it 'correctly updates attributes based on the new form data' do
        expect(result).to have_attributes(
          form_name: '21-0966',
          row_id: 5382,
          url: 'https://www.vba.va.gov/pubs/forms/VBA-21-0966-ARE.pdf',
          title: 'Intent to File a Claim for Compensation and/or Pension, or Survivors Pension and/or DIC',
          first_issued_on: Date.new(2019, 11, 7),
          last_revision_on: Date.new(2018, 8, 22),
          pages: 1,
          sha256: 'b1ee32f44d7c17871e4aba19101ba6d55742674e6e1627498d618a356ea6bc78',
          valid_pdf: true,
          ranking: nil,
          tags: '21-0966',
          language: 'en',
          related_forms: ['10-10d'],
          benefit_categories: [{ 'name' => 'Pension', 'description' => 'VA pension benefits' }],
          va_form_administration: 'Veterans Benefits Administration',
          form_type: 'benefit',
          form_usage: 'Someusagehtml',
          form_tool_intro: 'some intro text',
          form_tool_url: 'https://www.va.gov/education/apply-for-education-benefits/application/1995/introduction',
          form_details_url: 'https://www.va.gov/find-forms/about-form-21-0966',
          deleted_at: nil
        )
      end
    end

    context 'when the form url returns a 404' do
      let(:form_data) { invalid_url_form_data }
      let(:invalid_form_url) { 'https://www.vba.va.gov/pubs/forms/not_a_valid_url.pdf' }
      let(:result) do
        form = VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf:, row_id:)
        with_settings(Settings.va_forms.slack, enabled: enable_notifications) do
          VCR.use_cassette(not_found_pdf_cassette) do
            form_builder.perform(form_data)
          end
        end
        form.reload
      end

      it 'marks the form as invalid' do
        expect(result.valid_pdf).to be(false)
      end

      it 'updates the form url' do
        expect(result.url).to eql(invalid_form_url)
      end

      it 'clears the sha256' do
        expect(result.sha256).to be_nil
      end

      it 'correctly updates the remaining attributes based on the form data' do
        expect(result).to have_attributes(
          form_name: '21-0966',
          row_id: 5382,
          title: 'Intent to File a Claim for Compensation and/or Pension, or Survivors Pension and/or DIC',
          first_issued_on: Date.new(2019, 11, 7),
          last_revision_on: Date.new(2018, 8, 22),
          pages: 1,
          ranking: nil,
          tags: '21-0966',
          language: 'en',
          related_forms: ['10-10d'],
          benefit_categories: [{ 'name' => 'Pension', 'description' => 'VA pension benefits' }],
          va_form_administration: 'Veterans Benefits Administration',
          form_type: 'benefit',
          form_usage: 'Someusagehtml',
          form_tool_intro: 'some intro text',
          form_tool_url: 'https://www.va.gov/education/apply-for-education-benefits/application/1995/introduction',
          form_details_url: 'https://www.va.gov/find-forms/about-form-21-0966',
          deleted_at: nil
        )
      end

      it 'notifies slack that the form url no longer returns a valid form' do
        result
        expect(VAForms::Slack::Messenger).to have_received(:new).with(
          {
            class: described_class.to_s,
            message: "URL for form #{form_name} no longer returns a valid PDF or web page.",
            form_url: invalid_form_url
          }
        )
        expect(slack_messenger).to have_received(:notify!)
      end
    end

    context 'when the form url returns a 500' do
      it 'raises an error' do
        VCR.use_cassette(server_error_pdf_cassette) do
          expect { form_builder.perform(form_data) }
            .to raise_error(described_class::FormFetchError, form_fetch_error_message)
        end
      end
    end

    context 'when the PDF is unchanged' do
      it 'keeps existing values without notifying slack' do
        expect(result.valid_pdf).to be(true)
        expect(result.sha256).to eq(valid_sha256)
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end

    context 'when the PDF has been marked as deleted' do
      let(:form_data) { deleted_form_data }

      it 'updates the deleted_at date' do
        expect(result.deleted_at.to_date.to_s).to eq('2020-07-16')
      end

      it 'sets valid_pdf to true and the sha256 to nil' do
        expect(result.valid_pdf).to be(false)
        expect(result.sha256).to be_nil
      end

      it 'does not raise a form fetch error' do
        expect { form_builder.perform(form_data) }
          .not_to raise_error
      end
    end

    context 'when the PDF was previously invalid' do
      let(:valid_pdf) { false }

      it 'updates valid_pdf to true without notifying slack' do
        expect(result.valid_pdf).to be(true)
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end

    context 'when the sha256 has changed' do
      let(:sha256) { 'arbitrary-old-sha256-value' }

      context 'and the url returns a PDF' do
        it 'updates the saved sha256 and notifies slack' do
          expect(result.sha256).to eq(valid_sha256)
          expect(VAForms::Slack::Messenger).to have_received(:new).with(
            {
              class: described_class.to_s,
              message: "PDF contents of form #{form_name} have been updated."
            }
          )
          expect(slack_messenger).to have_received(:notify!)
        end
      end

      context 'and the url returns a web page' do
        before do
          allow_any_instance_of(Faraday::Utils::Headers).to receive(:[]).with(:user_agent).and_call_original
          allow_any_instance_of(Faraday::Utils::Headers).to receive(:[]).with('Content-Type').and_return('text/html')
        end

        it 'updates the saved sha256 but does not notify slack' do
          expect(result.sha256).to eq(valid_sha256)
          expect(slack_messenger).not_to have_received(:notify!)
        end
      end
    end

    context 'when all retries are exhausted' do
      let(:error) { RuntimeError.new('an error occurred!') }
      let(:msg) do
        {
          'jid' => 123,
          'class' => described_class.to_s,
          'error_class' => 'RuntimeError',
          'error_message' => 'an error occurred!',
          'args' => [{
            'fieldVaFormNumber' => form_name,
            'fieldVaFormRowId' => row_id
          }]
        }
      end

      it 'increments the StatsD counter' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(StatsD).to(receive(:increment))
                        .with("#{described_class::STATSD_KEY_PREFIX}.exhausted", tags: { form_name:, row_id: })
                        .exactly(1).time
        end
      end

      it 'logs a warning to the Rails console' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(Rails.logger).to receive(:warn).with(
            'VAForms::FormBuilder retries exhausted',
            {
              job_id: 123,
              error_class: 'RuntimeError',
              error_message: 'an error occurred!',
              form_name:,
              row_id:,
              form_data: {
                'fieldVaFormNumber' => form_name,
                'fieldVaFormRowId' => row_id
              }
            }
          )
        end
      end

      context 'and the error was a form fetch error' do
        let(:error) { described_class::FormFetchError.new(form_fetch_error_message) }
        let(:msg) do
          {
            'jid' => 456,
            'error_class' => described_class::FormFetchError.to_s,
            'error_message' => form_fetch_error_message,
            'args' => [{
              'fieldVaFormNumber' => form_name,
              'fieldVaFormRowId' => row_id,
              'fieldVaFormUrl' => {
                'uri' => url
              }
            }]
          }
        end

        it 'updates the url-related form attributes' do
          form = VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf:, row_id:)

          described_class.within_sidekiq_retries_exhausted_block(msg, error) do
            expect(StatsD).to(receive(:increment)).exactly(1).time
            expect(Rails.logger).to receive(:warn)
          end

          form.reload
          expect(form.valid_pdf).to be(false)
          expect(form.sha256).to be_nil
          expect(form.url).to eq(url)
        end

        context 'and the form was previously valid' do
          let(:expected_notify) do
            {
              class: described_class.to_s,
              message: "URL for form #{form_name} no longer returns a valid PDF or web page.",
              form_url: url
            }
          end

          it 'notifies Slack that the form is now invalid' do
            VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf: true, row_id:)

            described_class.within_sidekiq_retries_exhausted_block(msg, error) do
              expect(VAForms::Slack::Messenger).to receive(:new).with(expected_notify).and_return(slack_messenger)
              expect(slack_messenger).to receive(:notify!)
            end
          end
        end

        context 'and the form was not previously valid' do
          it 'does not notify Slack' do
            VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf: false, row_id:)

            described_class.within_sidekiq_retries_exhausted_block(msg, error) do
              expect(VAForms::Slack::Messenger).not_to receive(:new)
              expect(slack_messenger).not_to receive(:notify!)
            end
          end
        end
      end
    end
  end
end
# rubocop:enable Layout/LineLength
