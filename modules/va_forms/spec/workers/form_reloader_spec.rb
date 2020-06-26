# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe VaForms::FormReloader, type: :job do
  subject { described_class }

  let(:form_reloader) { VaForms::FormReloader.new }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'importer' do
    it 'loads the initial set of data' do
      VCR.use_cassette('va_forms/forms') do
        allow_any_instance_of(VaForms::FormReloader).to receive(:get_sha256) { SecureRandom.hex(12) }
        expect do
          form_reloader.load_page(current_page: 0)
        end.to change(VaForms::Form, :count).by(25)
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
        form = VaForms::Form.new(url: 'http://www.vba.va.gov/pubs/forms/26-8599.pdf')
        form = form_reloader.update_sha256(form)
        expect(form.valid_pdf).to eq(true)
        expect(form.sha256).to eq('f99d16fb94859065855dd71e3b253571229b31d4d46ca08064054b15207598bc')
      end
    end

    it 'fails to update the sha256 when forms are submitted' do
      VCR.use_cassette('va_forms/fails') do
        form = VaForms::Form.new(url: 'http://www.vba.va.gov/pubs/forms/26-85992.pdf')
        form = form_reloader.update_sha256(form)
        expect(form.valid_pdf).to eq(false)
        expect(form.sha256).to eq(nil)
      end
    end

    it 'expands relative urls' do
      test_url = './medical/pdf/vha10-10171-fill.pdf'
      final_url = VaForms::FormReloader.new.get_full_url(test_url)
      expect(final_url).to eq('https://www.va.gov/vaforms/medical/pdf/vha10-10171-fill.pdf')
    end

    describe 'stale forms' do
      it 'marks missing forms as invalid' do
        allow_any_instance_of(VaForms::FormReloader).to receive(:get_sha256) { SecureRandom.hex(12) }
        form_name = '26-8736a'

        # Populate the DB to include 26-8736a
        VCR.use_cassette('va_forms/forms') do
          form_reloader.load_page(current_page: 0)
          expect(VaForms::Form.find_by(form_name: form_name).valid_pdf).to eq(true)
        end

        # Run the build again with 26-8736a omitted from the HTML
        VCR.use_cassette('va_forms/forms-missing-26-8736a') do
          form_reloader = VaForms::FormReloader.new
          form_reloader.load_page(current_page: 0)
          form_reloader.mark_stale_forms
          expect(VaForms::Form.find_by(form_name: form_name).valid_pdf).to eq(false)
        end
      end
    end

    describe 'date parsing checks' do
      it 'parses date when month day year' do
        date_string = '7/30/2018'
        expect(VaForms::FormReloader.new.parse_date(date_string).to_s).to eq('2018-07-30')
      end

      it 'parses date when month and year' do
        date_string = '07/2018'
        expect(VaForms::FormReloader.new.parse_date(date_string).to_s).to eq('2018-07-01')
      end
    end
  end
end
