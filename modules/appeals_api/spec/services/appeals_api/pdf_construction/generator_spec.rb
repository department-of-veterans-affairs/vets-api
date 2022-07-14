# frozen_string_literal: true

# DEVELOPER NOTE: The `match_pdf` matcher only checks against the extracted text of the pdf. It cannot verify things
# like checkboxes being checked/unchecked or radio button selection (We tried. That way madness lies.). You will need
# to manually open the generated pdfs to verify those items are behaving as expected.

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::PdfConstruction::Generator do
  include FixtureHelpers
  include SchemaHelpers

  let(:appeal) { create(:notice_of_disagreement) }

  describe '#generate' do
    it 'returns a pdf path' do
      result = described_class.new(appeal).generate
      expect(result[-4..]).to eq('.pdf')
    end

    context 'Notice Of Disagreement' do
      context 'pdf minimum content verification' do
        let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_minimum.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_extra.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'v2' do
        context 'pdf content verification' do
          let(:nod_v2) { create(:notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(nod_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_10182.pdf', version: 'v2')
            expect(generated_pdf).to match_pdf expected_pdf
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf extra content verification' do
          let(:extra_nod_v2) { create(:extra_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            data = extra_nod_v2.form_data
            extra_nod_v2.form_data = data

            generated_pdf = described_class.new(extra_nod_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_10182_extra.pdf', version: 'v2')
            expect(generated_pdf).to match_pdf expected_pdf
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf minimal content verification' do
          let(:minimal_nod_v2) { create(:minimal_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(minimal_nod_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_10182_minimal.pdf', version: 'v2')
            expect(generated_pdf).to match_pdf expected_pdf
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf max length content verification' do
          let(:schema) { read_schema('10182.json', 'v2') }
          let(:nod) { build(:extra_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }
          let(:data) { override_max_lengths(nod, schema) }

          # TODO: Try to figure out why the CI runner interprets our expected pdf differently than locally, despite
          #       being visually identical.
          # e.g. on CI, some text is interpreted in a slightly different order or W's are added in odd places.
          xit 'generates the expected pdf' do
            nod.form_data = data
            # we tried to use JSON_SCHEMER, but it did not work with our headers, and chose not to invest more time atm.
            nod.auth_headers['X-VA-SSN'] = 'W' * 9
            nod.auth_headers['X-VA-First-Name'] = 'W' * 30
            nod.auth_headers['X-VA-Middle-Initial'] = 'W' * 1
            nod.auth_headers['X-VA-Last-Name'] = 'W' * 40
            nod.auth_headers['X-VA-Claimant-First-Name'] = 'W' * 30
            nod.auth_headers['X-VA-Claimant-Middle-Initial'] = 'W' * 1
            nod.auth_headers['X-VA-Claimant-Last-Name'] = 'W' * 40
            nod.auth_headers['X-VA-File-Number'] = 'W' * 9
            nod.auth_headers['X-Consumer-Username'] = 'W' * 255
            nod.auth_headers['X-Consumer-ID'] = 'W' * 255
            nod.save!

            generated_pdf = described_class.new(nod, version: 'v2').generate
            expected_pdf = fixture_filepath('expected_10182_maxlength.pdf', version: 'v2')

            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end
      end
    end

    context 'Higher Level Review' do
      context 'v2' do
        context 'pdf verification' do
          let(:higher_level_review_v2) { create(:higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(higher_level_review_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996.pdf', version: 'v2')
            # Manually test changes to radio buttons
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf extra content verification' do
          let(:extra_hlr_v2) { create(:extra_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(extra_hlr_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_extra.pdf', version: 'v2')
            # Manually test changes to radio buttons
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf minimum content verification' do
          let(:minimal_hlr_v2) { create(:minimal_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(minimal_hlr_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_minimum.pdf', version: 'v2')
            # Manually test changes to radio buttons
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'special character verification' do
          it 'allows certain typography characters into Windows-1252' do
            hlr = build(:minimal_higher_level_review_v2)
            hlr.form_data['included'][0]['attributes']['issue'] = 'Smartquotes: “”‘’'
            hlr.save!
            generated_pdf = described_class.new(hlr, version: 'V2').generate
            generated_reader = PDF::Reader.new(generated_pdf)
            expect(generated_reader.pages[1].text).to include 'Smartquotes: “”‘’'
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end

          it 'removes characters that fall outsize Windows-1252 charset that cannot be downgraded' do
            hlr = build(:minimal_higher_level_review_v2)
            hlr.form_data['included'][0]['attributes']['issue'] = '∑mer allergies'
            hlr.save!
            generated_pdf = described_class.new(hlr, version: 'V2').generate
            generated_reader = PDF::Reader.new(generated_pdf)
            expect(generated_reader.pages[1].text).to include 'mer allergies'
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        # rubocop:disable Layout/LineLength
        context 'pdf max length content verification' do
          let(:schema) { read_schema('200996.json', 'v2') }
          let(:hlr) { build(:extra_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }
          let(:data) { override_max_lengths(hlr, schema) }

          it 'generates the expected pdf' do
            # phone strings are only allowed to be 20 char in length, so we are overriding it.
            allow_any_instance_of(AppealsApi::PdfConstruction::HigherLevelReview::V2::FormData).to receive(:veteran_phone_string).and_return('+WWW-WWWWWWWWWWWWWWW')
            allow_any_instance_of(AppealsApi::PdfConstruction::HigherLevelReview::V2::FormData).to receive(:claimant_phone_string).and_return('+WWW-WWWWWWWWWWWWWWW')

            hlr.form_data = data
            # TODO: update countryCodeISO2 in expected_200996_maxlength.pdf with expected override_max_lengths tranforms
            hlr.form_data['data']['attributes']['veteran']['address']['countryCodeISO2'] = 'US'
            hlr.form_data['data']['attributes']['claimant']['address']['countryCodeISO2'] = 'US'

            # we tried to use JSON_SCHEMER for headers, but it did not work with our headers, and chose not to invest more time atm.
            hlr.auth_headers['X-VA-First-Name'] = 'W' * 30
            hlr.auth_headers['X-VA-Middle-Initial'] = 'W' * 1
            hlr.auth_headers['X-VA-Last-Name'] = 'W' * 40
            hlr.auth_headers['X-VA-File-Number'] = 'W' * 9
            hlr.auth_headers['X-VA-SSN'] = 'W' * 9
            hlr.auth_headers['X-VA-Insurance-Policy-Number'] = 'W' * 18
            hlr.auth_headers['X-VA-Claimant-SSN'] = 'W' * 9
            hlr.auth_headers['X-VA-Claimant-First-Name'] = 'W' * 255
            hlr.auth_headers['X-VA-Claimant-Middle-Initial'] = 'W' * 1
            hlr.auth_headers['X-VA-Claimant-Last-Name'] = 'W' * 255
            hlr.auth_headers['X-Consumer-Username'] = 'W' * 255
            hlr.auth_headers['X-Consumer-ID'] = 'W' * 255
            hlr.save!

            generated_pdf = described_class.new(hlr, version: 'v2').generate
            expected_pdf = fixture_filepath('expected_200996_maxlength.pdf', version: 'v2')

            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end
      end
    end

    context 'Supplemental Claim' do
      context 'pdf verification' do
        let(:supplemental_claim) { create(:supplemental_claim, evidence_submission_indicated: true, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(supplemental_claim, version: 'V2').generate
          expected_pdf = fixture_filepath('expected_200995.pdf', version: 'v2')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        let(:extra_supplemental_claim) { create(:extra_supplemental_claim, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(extra_supplemental_claim, version: 'V2').generate
          expected_pdf = fixture_filepath('expected_200995_extra.pdf', version: 'v2')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf max length content verification' do
        let(:schema) { read_schema('200995.json', 'v2') }
        let(:sc) { build(:extra_supplemental_claim, created_at: '2021-02-03T14:15:16Z') }
        let(:data) { override_max_lengths(sc, schema) }

        it 'generates the expected pdf' do
          allow_any_instance_of(AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData).to receive(:signing_appellant_phone).and_return('+WWW-WWWWWWWWWWWWWWW')
          allow_any_instance_of(AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData).to receive(:signing_appellant_zip_code).and_return('W' * 16)
          allow_any_instance_of(AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData).to receive(:signing_appellant_number_and_street).and_return("#{'W' * 60} #{'W' * 30} #{'W' * 10}")
          allow_any_instance_of(AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData).to receive(:signing_appellant_city).and_return('W' * 60)
          allow_any_instance_of(AppealsApi::PdfConstruction::SupplementalClaim::V2::FormData).to receive(:signing_appellant_email).and_return('W' * 255)

          sc.form_data = data
          # we tried to use JSON_SCHEMER, but it did not work with our headers, and chose not to invest more time atm.
          sc.auth_headers['X-VA-First-Name'] = 'W' * 30
          sc.auth_headers['X-VA-Last-Name'] = 'W' * 40
          sc.auth_headers['X-VA-Claimant-First-Name'] = 'W' * 30
          sc.auth_headers['X-VA-Claimant-Last-Name'] = 'W' * 40
          sc.auth_headers['X-Consumer-Username'] = 'W' * 255
          sc.auth_headers['X-Consumer-ID'] = 'W' * 255
          sc.save!

          generated_pdf = described_class.new(sc, version: 'v2').generate
          expected_pdf = fixture_filepath('expected_200995_maxlength.pdf', version: 'v2')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end
    end
    # rubocop:enable Layout/LineLength
  end
end
