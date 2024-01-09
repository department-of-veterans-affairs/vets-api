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
  let(:form_fetch_error_message) { described_class::FORM_FETCH_ERROR_MESSAGE }

  before do
    Sidekiq::Job.clear_all
    allow(Rails.logger).to receive(:error)
    allow(VAForms::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    allow(StatsD).to receive(:increment)
  end

  describe '#perform' do
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
      form = VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf:, row_id:)
      with_settings(Settings.va_forms.slack, enabled: enable_notifications) do
        VCR.use_cassette(cassette) do
          form_builder.perform(form_data)
        end
      end
      form.reload
    end

    context 'when the form url returns a valid body' do
      let(:cassette) { valid_pdf_cassette }

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
      let(:form_data) { bad_url_form_data }

      it 'raises an error' do
        VCR.use_cassette(not_found_pdf_cassette) do
          expect { form_builder.perform(form_data) }.to raise_error(RuntimeError, form_fetch_error_message)
        end
      end
    end

    context 'when the PDF is unchanged' do
      xit 'keeps existing values without notifying slack - pending temporarily' do
        expect(result.valid_pdf).to be(true)
        expect(result.sha256).to eq(valid_sha256)
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end

    context 'when the PDF has been marked as deleted (even though the URL is valid)' do
      let(:form_data) { deleted_form_data }
      xit 'includes a deleted_at date but still sets other values as usual and does not notify - pending temporarily' do
        expect(result.deleted_at.to_date.to_s).to eq('2020-07-16')
        expect(result.valid_pdf).to be(true)
        expect(result.sha256).to eq(valid_sha256)
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end

    context 'when the PDF was previously invalid' do
      let(:valid_pdf) { false }
      xit 'updates valid_pdf to true without notifying slack - pending temporarily' do
        expect(result.valid_pdf).to be(true)
        expect(slack_messenger).not_to have_received(:notify!)
      end
    end

    context 'when the sha256 has changed' do
      let(:sha256) { 'arbitrary-old-sha256-value' }

      context 'and the url returns a PDF' do
        xit 'updates the saved sha256 and notifies slack - pending temporarily' do
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
        xit 'updates the saved sha256 but does not notify slack - pending temporarily' do
          expect(result.sha256).to eq(valid_sha256)
          expect(slack_messenger).not_to have_received(:notify!)
        end
      end
    end

    context 'when all retries are exhausted' do
      let(:msg) { { 'jid' => 123, 'args' => { 'fieldVaFormNumber' => form_name, 'fieldVaFormRowId' => row_id } } }
      let(:error) { RuntimeError.new('an error occurred!') }
      let(:error_message) do
        "#{described_class.class.name} failed to import form_name: #{form_name}, row_id: #{row_id} into forms database."
      end

      it 'logs an error' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(Rails.logger).to receive(:error).with(error_message, error.message)
        end
      end

      it 'increments the StatsD counter' do
        described_class.within_sidekiq_retries_exhausted_block(msg, error) do
          expect(StatsD).to(receive(:increment))
                        .with("#{described_class::STATSD_KEY_PREFIX}.failure", tags: { form_name:, row_id: })
                        .exactly(1).time
        end
      end

      context 'and the error was a form fetch error' do
        let(:msg) do
          {
            'jid' => 123,
            'args' => {
              'fieldVaFormNumber' => form_name,
              'fieldVaFormRowId' => row_id,
              'fieldVaFormUrl' => {
                'uri' => url
              }
            }
          }
        end
        let(:error) { RuntimeError.new(form_fetch_error_message) }

        it 'updates the url-related form attributes' do
          form = VAForms::Form.create!(url:, form_name:, sha256:, title:, valid_pdf:, row_id:)

          described_class.within_sidekiq_retries_exhausted_block(msg, error) do
            expect(Rails.logger).to receive(:error).with(error_message, error.message)
          end

          form.reload
          expect(form.valid_pdf).to be_falsey
          expect(form.sha256).to be_nil
          expect(form.url).to eq(url)
        end

        context 'and the form was previously valid' do
          let(:expected_notify) do
            {
              class: described_class.class.name,
              message: "URL for form_name: #{form_name}, row_id: #{row_id} no longer returns a valid PDF or web page.",
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
