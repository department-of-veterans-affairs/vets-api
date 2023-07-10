# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::PdfConstruction::Generator do
  include FixtureHelpers
  include SchemaHelpers

  context 'Higher-Level Review' do
    # opts[:api_version] - underscored name of the API whose schema to use when creating a Higher-Level Review
    # opts[:api_version] - api_version to use when creating a Notice of Disagreement
    # opts[:pdf_version] - version of PDF to render
    shared_examples 'shared HLR v2 and v3 generator examples' do |opts|
      let(:created_at) { '2021-02-03T14:15:16Z' }
      let(:fixture_name) { 'expected_200996.pdf' }
      let(:hlr) { create("higher_level_review_#{opts[:api_version]}".to_sym, created_at:) }
      let(:generated_pdf) { described_class.new(hlr, pdf_version: opts[:pdf_version]).generate }
      let(:expected_pdf) { fixture_filepath("pdfs/#{opts[:pdf_version]}/#{fixture_name}") }

      after { FileUtils.rm_f generated_pdf }

      it 'generates the expected pdf' do
        expect(generated_pdf).to match_pdf(expected_pdf)
      end

      context 'with minimum content' do
        let(:fixture_name) { 'expected_200996_minimum.pdf' }
        let(:hlr) { create("minimal_higher_level_review_#{opts[:api_version]}".to_sym, created_at:) }

        it 'generates the expected pdf' do
          expect(generated_pdf).to match_pdf(expected_pdf)
        end
      end

      context 'with extra content' do
        let(:fixture_name) { 'expected_200996_extra.pdf' }
        let(:hlr) { create("extra_higher_level_review_#{opts[:api_version]}".to_sym, created_at:) }

        # FIXME: This is skipped when api_version is v0 because the v0 output contains inconsistent whitespace
        # compared to the v2 output. There is no actual visual difference in outputs regardless of the api_version
        # in use, but these tests will fail nonetheless if they run where api_version = v0.
        it 'generates the expected pdf', skip: opts[:api_version] == 'v0' do
          expect(generated_pdf).to match_pdf(expected_pdf)
        end
      end

      context 'with max length' do
        let(:fixture_name) { 'expected_200996_maxlength.pdf' }
        let(:hlr) do
          (opts[:form_data] || {}).each do |field_name, field_value|
            allow_any_instance_of(
              "AppealsApi::PdfConstruction::HigherLevelReview::#{opts[:pdf_version].upcase}::FormData".constantize
            ).to receive(field_name).and_return(field_value)
          end

          create("extra_higher_level_review_#{opts[:api_version]}".to_sym, created_at:) do |appeal|
            appeal.form_data = override_max_lengths(
              appeal,
              read_schema('200996.json', opts[:api_name], opts[:api_version])
            )
            # TODO: update countryCodeISO2 in expected_200996_maxlength.pdf with expected override_max_lengths values
            appeal.form_data['data']['attributes']['veteran']['address']['countryCodeISO2'] = 'US'
            appeal.form_data['data']['attributes']['claimant']['address']['countryCodeISO2'] = 'US'
            appeal.auth_headers.merge!(
              {
                'X-VA-First-Name' => 'W' * 30,
                'X-VA-Middle-Initial' => 'W',
                'X-VA-Last-Name' => 'W' * 40,
                'X-VA-File-Number' => 'W' * 9,
                'X-VA-SSN' => 'W' * 9,
                'X-VA-Insurance-Policy-Number' => 'W' * 18,
                'X-VA-NonVeteranClaimant-SSN' => 'W' * 9,
                'X-VA-NonVeteranClaimant-First-Name' => 'W' * 255,
                'X-VA-NonVeteranClaimant-Middle-Initial' => 'W',
                'X-VA-NonVeteranClaimant-Last-Name' => 'W' * 255,
                'X-Consumer-Username' => 'W' * 255,
                'X-Consumer-ID' => 'W' * 255
              }
            )
          end
        end

        it 'generates the expected pdf' do
          expect(generated_pdf).to match_pdf(expected_pdf)
        end
      end

      context 'with special characters' do
        context 'when compatible with Windows-1252' do
          let(:text) { 'Smartquotes: “”‘’' }
          let(:hlr) do
            create("higher_level_review_#{opts[:api_version]}", created_at:) do |appeal|
              appeal.form_data['included'][0]['attributes']['issue'] = text
            end
          end

          it 'does not remove the characters' do
            generated_reader = PDF::Reader.new(generated_pdf)
            expect(generated_reader.pages[1].text).to include text
          end
        end

        context 'when incompatible with Windows-1252 and unable to downgrade' do
          let(:normal_text) { 'allergies' }
          let(:special_text) { '∑' }
          let(:hlr) do
            create("higher_level_review_#{opts[:api_version]}", created_at:) do |appeal|
              appeal.form_data['included'][0]['attributes']['issue'] = "#{special_text}#{normal_text}"
            end
          end

          it 'removes the characters' do
            generated_reader = PDF::Reader.new(generated_pdf)
            expect(generated_reader.pages[1].text).to include normal_text
            expect(generated_reader.pages[1].text).not_to include special_text
          end
        end
      end
    end

    context "when the HLR's api_version is v2" do
      context 'with PDF v2' do
        include_examples 'shared HLR v2 and v3 generator examples', {
          api_name: 'decision_reviews',
          api_version: 'v2',
          pdf_version: 'v2',
          form_data: {
            veteran_international_number: '+WWW-WWWWWWWWWWWWWWW',
            claimant_international_number: '+WWW-WWWWWWWWWWWWWWW'
          }
        }
      end

      context 'with PDF v3' do
        include_examples 'shared HLR v2 and v3 generator examples', {
          api_name: 'decision_reviews',
          api_version: 'v2',
          pdf_version: 'v3',
          form_data: {
            veteran_international_phone: '+WWW-WWWWWWWWWWWWWWW',
            claimant_international_phone: '+WWW-WWWWWWWWWWWWWWW',
            rep_international_phone: '+WWW-WWWWWWWWWWWWWWW'
          }
        }
      end
    end

    context "when the HLR's api_version is v0" do
      context 'with PDF v3' do
        include_examples 'shared HLR v2 and v3 generator examples', {
          api_name: 'higher_level_reviews',
          api_version: 'v0',
          pdf_version: 'v3',
          form_data: {
            veteran_international_phone: '+WWW-WWWWWWWWWWWWWWW',
            claimant_international_phone: '+WWW-WWWWWWWWWWWWWWW',
            rep_international_phone: '+WWW-WWWWWWWWWWWWWWW'
          }
        }
      end
    end
  end
end
