# frozen_string_literal: true

require 'rails_helper'
require VAForms::Engine.root.join('spec', 'rails_helper.rb')

# rubocop:disable Layout/LineLength
RSpec.describe VAForms::FormBuilder, type: :job do
  subject { described_class }

  let(:form_builder) { described_class.new }
  let(:slack_messenger) { instance_double(VAForms::Slack::Messenger) }

  let(:default_form_data) { JSON.parse(File.read(VAForms::Engine.root.join('spec', 'fixtures', 'gql_form.json'))) }
  let(:bad_url_form_data) { JSON.parse(File.read(VAForms::Engine.root.join('spec', 'fixtures', 'gql_form_invalid_url.json'))) }
  let(:deleted_form_data) { JSON.parse(File.read(VAForms::Engine.root.join('spec', 'fixtures', 'gql_form_deleted.json'))) }

  let(:valid_pdf_cassette) { 'va_forms/valid_pdf' }
  let(:not_found_pdf_cassette) { 'va_forms/pdf_not_found' }
  let(:error_message) { 'A valid PDF could not be fetched' }

  before do
    Sidekiq::Worker.clear_all
    allow(Rails.logger).to receive(:error)
    allow(VAForms::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
    let(:form_data) { bad_url_form_data }

    context 'when an exception is raised while updating the form' do
      it 'logs the error and increments the StatsD failure counter, then reraises' do
        expect(Rails.logger).to(receive(:error))
        expect(StatsD).to(receive(:increment))
                      .with("#{described_class::STATSD_KEY_PREFIX}.failure", tags: { form_name: '21-0966' })
                      .exactly(1).time

        VCR.use_cassette(not_found_pdf_cassette) do
          expect { form_builder.perform(form_data) }.to raise_error(RuntimeError, error_message)
        end
      end
    end
  end

  describe '#build_and_save_form' do
    let(:cassette) { nil }
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
      VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf:, row_id:)
      with_settings(Settings.va_forms.slack, enabled: enable_notifications) do
        VCR.use_cassette(cassette) do
          form_builder.build_and_save_form(form_data)
        end
      end
    end

    context 'when the form url returns a valid body' do
      let(:cassette) { valid_pdf_cassette }

      it 'correctly updates attributes based on the new form data' do
        expect(result).to have_attributes(
          language: 'en',
          related_forms: ['10-10d'],
          benefit_categories: [{ 'name' => 'Pension', 'description' => 'VA pension benefits' }],
          va_form_administration: 'Veterans Benefits Administration',
          row_id: 5382,
          form_type: 'benefit',
          form_usage: 'Someusagehtml',
          form_tool_intro: 'some intro text',
          form_tool_url: 'https://www.va.gov/education/apply-for-education-benefits/application/1995/introduction',
          form_details_url: 'https://www.va.gov/find-forms/about-form-21-0966',
          deleted_at: nil
        )
      end

      context 'and the PDF is unchanged' do
        it 'keeps existing values without notifying slack' do
          expect(result.valid_pdf).to be(true)
          expect(result.sha256).to eq(valid_sha256)
          expect(slack_messenger).not_to have_received(:notify!)
        end
      end

      context 'but the PDF has been marked as deleted (even though the URL is valid)' do
        let(:form_data) { deleted_form_data }

        it 'includes a deleted_at date but still sets other values as usual and does not notify' do
          expect(result.deleted_at.to_date.to_s).to eq('2020-07-16')
          expect(result.valid_pdf).to be(true)
          expect(result.sha256).to eq(valid_sha256)
          expect(slack_messenger).not_to have_received(:notify!)
        end
      end

      context 'and the PDF was previously invalid' do
        let(:valid_pdf) { false }

        it 'updates valid_pdf to true without notifying slack' do
          expect(result.valid_pdf).to be(true)
          expect(slack_messenger).not_to have_received(:notify!)
        end
      end

      context 'and the the sha256 has changed' do
        let(:sha256) { 'arbitrary-old-sha256-value' }

        context 'when the url returns a PDF' do
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

        context 'when the url returns a web page' do
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
    end

    context 'when the form url returns an error response' do
      let(:bad_url) { 'https://www.vba.va.gov/pubs/forms/not_a_valid_url.pdf' }
      let(:form_data) { bad_url_form_data }
      let(:cassette) { not_found_pdf_cassette }

      before { form_builder.instance_variable_set(:@current_retry, current_retry) }

      context 'when the job has remaining tries' do
        let(:current_retry) { described_class::RETRIES - 1 }

        it 'raises an exception and logs an error to the rails console' do
          expect { result }.to raise_error(error_message)
          error_details = { url: bad_url, response_code: 404, content_type: 'text/html', current_retry: }
          expect(Rails.logger).to have_received(:error).with(error_message, error_details)
        end
      end

      context 'when there are no more tries remaining' do
        let(:current_retry) { described_class::RETRIES }

        it 'sets valid_pdf to false and notifies slack that the pdf is no longer valid' do
          expect(result.valid_pdf).to eq(false)
          expect(VAForms::Slack::Messenger).to have_received(:new).with(
            {
              class: described_class.to_s,
              message: "URL for form #{form_name} no longer returns a valid PDF or web page.",
              form_url: bad_url
            }
          )
          expect(slack_messenger).to have_received(:notify!)
        end
      end
    end
  end

  describe '#expand_va_url' do
    it 'expands relative urls' do
      test_url = './medical/pdf/vha10-10171-fill.pdf'
      final_url = described_class.new.expand_va_url(test_url)
      expect(final_url).to eq('https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf')
    end
  end

  describe '#notify_slack' do
    let(:message) { 'test message' }
    let(:attrs) { {} }
    let(:enabled) { true }

    before { with_settings(Settings.va_forms.slack, enabled:) { described_class.new.notify_slack(message, **attrs) } }

    context 'when the setting is present' do
      it 'sends a notification' do
        expect(VAForms::Slack::Messenger).to have_received(:new).with(
          { class: described_class.to_s, message: }
        )
        expect(slack_messenger).to have_received(:notify!)
      end

      context 'when extra attributes are included with the message' do
        let(:attrs) { { extra_detail: 'example' } }

        it 'includes the extra attributes when notifying' do
          expect(VAForms::Slack::Messenger).to have_received(:new).with(
            { class: described_class.to_s, message:, **attrs }
          )
          expect(slack_messenger).to have_received(:notify!)
        end
      end
    end

    context 'when the setting is not present' do
      let(:enabled) { false }

      it 'does not notify' do
        expect(VAForms::Slack::Messenger).not_to have_received(:new)
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end
  end

  describe '#parse_date' do
    it 'parses date when month day year' do
      date_string = '2018-7-30'
      expect(described_class.new.parse_date(date_string).to_s).to eq('2018-07-30')
    end

    it 'parses date when month and year' do
      date_string = '07-2018'
      expect(described_class.new.parse_date(date_string).to_s).to eq('2018-07-01')
    end
  end
end
# rubocop:enable Layout/LineLength
