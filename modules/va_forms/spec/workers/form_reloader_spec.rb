# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAForms::FormReloader, type: :job do
  subject { described_class }

  let(:form_reloader) { VAForms::FormReloader.new }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'importer' do
    it 'loads the initial set of data' do
      VCR.use_cassette('va_forms/gql_forms') do
        allow_any_instance_of(VAForms::FormReloader).to receive(:get_sha256) { SecureRandom.hex(12) }
        expect do
          form_reloader.perform
        end.to change(VAForms::Form, :count).by(10)
      end
    end

    it 'gets the sha256 when contents are a Tempfile' do
      VCR.use_cassette('va_forms/tempfile') do
        url = 'http://www.vba.va.gov/pubs/forms/26-8599.pdf'
        sha256 = form_reloader.get_sha256(URI.parse(url).open)
        expect(sha256).to eq('f99d16fb94859065855dd71e3b253571229b31d4d46ca08064054b15207598bc')
      end
    end

    it 'updates the sha256 when forms are submitted' do
      VCR.use_cassette('va_forms/stringio') do
        form = VAForms::Form.new(url: 'http://www.vba.va.gov/pubs/forms/26-8599.pdf')
        form = form_reloader.update_sha256(form)
        expect(form.valid_pdf).to eq(true)
        expect(form.sha256).to eq('f99d16fb94859065855dd71e3b253571229b31d4d46ca08064054b15207598bc')
      end
    end

    it 'fails to update the sha256 when forms are submitted' do
      VCR.use_cassette('va_forms/fails') do
        form = VAForms::Form.new(url: 'http://www.vba.va.gov/pubs/forms/26-85992.pdf')
        form = form_reloader.update_sha256(form)
        expect(form.valid_pdf).to eq(false)
        expect(form.sha256).to eq(nil)
      end
    end

    it 'expands relative urls' do
      test_url = './medical/pdf/vha10-10171-fill.pdf'
      final_url = VAForms::FormReloader.new.expand_va_url(test_url)
      expect(final_url).to eq('https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf')
    end

    describe 'date parsing checks' do
      it 'parses date when month day year' do
        date_string = '2018-7-30'
        expect(VAForms::FormReloader.new.parse_date(date_string).to_s).to eq('2018-07-30')
      end

      it 'parses date when month and year' do
        date_string = '07-2018'
        expect(VAForms::FormReloader.new.parse_date(date_string).to_s).to eq('2018-07-01')
      end
    end

    describe 'verifying field values' do
      let(:form_json) do
        JSON.parse(File.read(Rails.root.join('modules', 'va_forms', 'spec', 'fixtures', 'gql_form.json')))
      end
      let(:deleted_form) do
        JSON.parse(File.read(Rails.root.join('modules', 'va_forms', 'spec', 'fixtures', 'gql_form_deleted.json')))
      end
      let(:job) { VAForms::FormReloader.new }

      before do
        @form = job.build_and_save_form(form_json)
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
        form = job.build_and_save_form(deleted_form)
        expect(form.deleted_at.to_date.to_s).to eq('2020-07-16')
      end
    end
  end
end
