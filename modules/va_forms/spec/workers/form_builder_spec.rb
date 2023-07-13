# frozen_string_literal: true

require 'rails_helper'
require VAForms::Engine.root.join('spec', 'rails_helper.rb')

RSpec.describe VAForms::FormBuilder, type: :job do
  subject { described_class }

  let(:form_builder) { described_class.new }
  let(:slack_messenger) { instance_double(VAForms::Slack::Messenger) }

  before do
    Sidekiq::Worker.clear_all

    allow(Rails.logger).to receive(:error)
    allow(VAForms::Slack::Messenger).to receive(:new).and_return(slack_messenger)
    allow(slack_messenger).to receive(:notify!)
    allow(StatsD).to receive(:increment)
  end

  describe '.perform' do
    let(:form_name) { 'VBA-21-0966-ARE' }
    let(:url) { 'http://www.vba.va.gov/pubs/forms/VBA-21-0966-ARE.pdf' }
    let(:sha256) { 'b1ee32f44d7c17871e4aba19101ba6d55742674e6e1627498d618a356ea6bc78' }
    let(:form) { VAForms::Form.new(url:, form_name:, sha256:) }

    let(:valid_pdf_cassette) { 'va_forms/valid_pdf' }
    let(:pdf_not_found_cassette) { 'va_forms/pdf_not_found' }
    let(:gql_form_cassette) { 'va_forms/gql_form' }
    let(:gql_form_invalid_url_cassette) { 'va_forms/gql_form_invalid_url' }

    context 'when the form url returns a successful response' do
      it 'sets valid_pdf: true' do
        VCR.use_cassette(valid_pdf_cassette) do
          updated_form = form_builder.validate_form(form)
          expect(updated_form.valid_pdf).to be(true)
        end
      end

      context 'and the sha256 has changed' do
        before { form.sha256 = '123' }

        it 'updates the sha256' do
          VCR.use_cassette(valid_pdf_cassette) do
            updated_form = form_builder.validate_form(form)
            expect(updated_form.sha256).to eq(sha256)
          end
        end

        context 'and the slack setting is enabled' do
          it 'notifies slack that the form has changed' do
            with_settings(Settings.va_forms.slack, enabled: true) do
              VCR.use_cassette(valid_pdf_cassette) do
                form_builder.validate_form(form)

                expected_details = {
                  class: described_class.to_s,
                  message: "Form #{form_name} has been updated.",
                  form_url: url
                }
                expect(VAForms::Slack::Messenger).to have_received(:new).with(expected_details)
                expect(slack_messenger).to have_received(:notify!)
              end
            end
          end
        end

        context 'and the slack setting is disabled' do
          it 'does not notify slack that the form has changed' do
            with_settings(Settings.va_forms.slack, enabled: false) do
              VCR.use_cassette(valid_pdf_cassette) do
                form_builder.validate_form(form)
                expect(slack_messenger).not_to have_received(:notify!)
              end
            end
          end
        end
      end

      context 'and the sha256 has not changed' do
        it 'does not notify slack that the form has changed' do
          with_settings(Settings.va_forms.slack, enabled: true) do
            VCR.use_cassette(valid_pdf_cassette) do
              form_builder.validate_form(form)
              expect(slack_messenger).not_to have_received(:notify!)
            end
          end
        end
      end
    end

    context 'when the form url does not return a successful response' do
      let(:url) { 'http://www.vba.va.gov/pubs/forms/not_a_valid_url.pdf' }

      context 'and it is the final retry' do
        before { form_builder.instance_variable_set(:@current_retry, described_class::RETRIES) }

        it 'sets valid_pdf: false' do
          VCR.use_cassette(pdf_not_found_cassette) do
            updated_form = form_builder.validate_form(form)
            expect(updated_form.valid_pdf).to be(false)
          end
        end

        context 'and the pdf was valid before the current job run' do
          before { form.valid_pdf = true }

          it 'notifies slack that the pdf is no longer valid' do
            with_settings(Settings.va_forms.slack, enabled: true) do
              VCR.use_cassette(pdf_not_found_cassette) do
                form_builder.validate_form(form)

                expected_details = {
                  class: described_class.to_s,
                  message: "Form #{form_name} no longer returns a valid PDF.",
                  form_url: url
                }
                expect(VAForms::Slack::Messenger).to have_received(:new).with(expected_details)
                expect(slack_messenger).to have_received(:notify!)
              end
            end
          end
        end

        context 'and the pdf was already invalid before the current job run' do
          before { form.valid_pdf = false }

          it 'does not notify slack that the pdf is no longer valid' do
            with_settings(Settings.va_forms.slack, enabled: true) do
              VCR.use_cassette(pdf_not_found_cassette) do
                form_builder.validate_form(form)
                expect(slack_messenger).not_to have_received(:notify!)
              end
            end
          end
        end
      end

      context 'and there are job retries remaining' do
        let(:error_message) { 'A valid PDF could not be fetched' }
        let(:response_code) { 404 }
        let(:content_type) { 'text/html' }
        let(:current_retry) { described_class::RETRIES - 1 }

        before { form_builder.instance_variable_set(:@current_retry, current_retry) }

        it 'raises an exception and logs an error to the rails console' do
          VCR.use_cassette(pdf_not_found_cassette) do
            expect { form_builder.validate_form(form) }.to raise_error(error_message)

            error_details = { response_code:, content_type:, url:, current_retry: }
            expect(Rails.logger).to have_received(:error).with(error_message, error_details)
          end
        end
      end
    end

    it 'expands relative urls' do
      test_url = './medical/pdf/vha10-10171-fill.pdf'
      final_url = described_class.new.expand_va_url(test_url)
      expect(final_url).to eq('https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf')
    end

    describe 'date parsing checks' do
      it 'parses date when month day year' do
        date_string = '2018-7-30'
        expect(described_class.new.parse_date(date_string).to_s).to eq('2018-07-30')
      end

      it 'parses date when month and year' do
        date_string = '07-2018'
        expect(described_class.new.parse_date(date_string).to_s).to eq('2018-07-01')
      end
    end

    describe 'verifying field values' do
      let(:form_json) do
        JSON.parse(Rails.root.join('modules', 'va_forms', 'spec', 'fixtures', 'gql_form.json').read)
      end
      let(:deleted_form) do
        JSON.parse(Rails.root.join('modules', 'va_forms', 'spec', 'fixtures', 'gql_form_deleted.json').read)
      end

      before do
        VCR.use_cassette(gql_form_cassette) do
          @form = form_builder.build_and_save_form(form_json)
        end
      end

      it 'loads language' do
        expect(@form.language).to eq('en')
      end

      it 'loads related form' do
        expect(@form.related_forms).to eq(['10-10d'])
      end

      it 'sets benefit categories' do
        expect(@form.benefit_categories).to eq(
          [
            { 'name' => 'Pension', 'description' => 'VA pension benefits' }
          ]
        )
      end

      it 'loads va form administration' do
        expect(@form.va_form_administration).to eq('Veterans Benefits Administration')
      end

      it 'loads row id' do
        expect(@form.row_id).to eq(5382)
      end

      it 'loads form type' do
        expect(@form.form_type).to eq('benefit')
      end

      it 'loads form usage' do
        expect(@form.form_usage).to eq('Someusagehtml')
      end

      it 'loads form tool fields' do
        expect(@form.form_tool_intro).to eq('some intro text')
        expect(@form.form_tool_url).to eq('https://www.va.gov/education/apply-for-education-benefits/application/1995/introduction')
      end

      it 'loads form detail url' do
        expect(@form.form_details_url).to eq('https://www.va.gov/find-forms/about-form-21-0966')
      end

      it 'sets deleted_at when present' do
        VCR.use_cassette(gql_form_cassette) do
          form = form_builder.build_and_save_form(deleted_form)
          expect(form.deleted_at.to_date.to_s).to eq('2020-07-16')
        end
      end
    end

    context 'when an exception is raised' do
      let(:form_json) do
        JSON.parse(Rails.root.join('modules', 'va_forms', 'spec', 'fixtures', 'gql_form_invalid_url.json').read)
      end
      let(:form_name) { '21-0966' }

      it 'increments the statsd failure counter' do
        VCR.use_cassette(gql_form_invalid_url_cassette) do
          expect { form_builder.perform(form_json) }.to raise_error(RuntimeError)
          expect(StatsD).to have_received(:increment)
            .with("#{described_class::STATSD_KEY_PREFIX}.failure", tags: { form_name: })
            .exactly(1).time
        end
      end
    end
  end
end
