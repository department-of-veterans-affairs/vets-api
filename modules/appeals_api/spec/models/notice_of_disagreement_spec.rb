# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreement, type: :model do
  include FixtureHelpers

  let(:auth_headers) { fixture_as_json 'valid_10182_headers.json', version: 'v1' }
  let(:form_data) { fixture_as_json 'valid_10182.json', version: 'v1' }
  let(:notice_of_disagreement) do
    review_option = form_data['data']['attributes']['boardReviewOption']
    build(:notice_of_disagreement, form_data:, auth_headers:, board_review_option: review_option)
  end

  describe '.build' do
    before { notice_of_disagreement.valid? }

    it('has no errors') do
      expect(notice_of_disagreement.errors).to be_empty
    end
  end

  # rubocop:disable Layout/LineLength
  describe '#validate_hearing_type_selection' do
    context "when board review option 'hearing' selected" do
      context 'when hearing type provided' do
        before do
          notice_of_disagreement.valid?
        end

        it 'does not throw an error' do
          expect(notice_of_disagreement.errors.count).to be 0
        end
      end

      context 'when hearing type missing' do
        before do
          form_data['data']['attributes'].delete('hearingTypePreference')
          notice_of_disagreement.valid?
        end

        it 'throws an error' do
          expect(notice_of_disagreement.errors.count).to be 1
          expect(notice_of_disagreement.errors.first.attribute).to eq(:'/data/attributes/hearingTypePreference')
          expect(notice_of_disagreement.errors.first.message).to eq(
            "If '/data/attributes/boardReviewOption' 'hearing' is selected, '/data/attributes/hearingTypePreference' must also be present"
          )
        end
      end
    end

    context "when board review option 'direct_review' or 'evidence_submission' is selected" do
      let(:form_data) { fixture_as_json 'valid_10182_minimum.json', version: 'v1' }

      context 'when hearing type provided' do
        before do
          notice_of_disagreement.form_data['data']['attributes']['hearingTypePreference'] = 'video_conference'
          notice_of_disagreement.valid?
        end

        it 'throws an error' do
          expect(notice_of_disagreement.errors.count).to be 1
          expect(notice_of_disagreement.errors.first.attribute).to eq(:'/data/attributes/hearingTypePreference')
          expect(notice_of_disagreement.errors.first.message).to eq(
            "If '/data/attributes/boardReviewOption' 'direct_review' or 'evidence_submission' is selected, '/data/attributes/hearingTypePreference' must not be selected"
          )
        end
      end
    end
  end
  # rubocop:enable Layout/LineLength

  describe '.date_from_string' do
    context 'when the string is in the correct format' do
      it { expect(described_class.date_from_string('2005-12-24')).to eq(Date.parse('2005-12-24')) }
    end

    context 'when the string is in the incorrect format' do
      it 'returns nil' do
        expect(described_class.date_from_string('200-12-24')).to be_nil
        expect(described_class.date_from_string('12-24-2005')).to be_nil
        expect(described_class.date_from_string('2005')).to be_nil
        expect(described_class.date_from_string('abc')).to be_nil
      end
    end
  end

  describe '#veteran_first_name' do
    it { expect(notice_of_disagreement.veteran_first_name).to eq 'Jäñe' }
  end

  describe '#veteran_last_name' do
    it { expect(notice_of_disagreement.veteran_last_name).to eq 'Doe' }
  end

  describe '#ssn' do
    it { expect(notice_of_disagreement.ssn).to eq '123456789' }
  end

  describe '#file_number' do
    it { expect(notice_of_disagreement.file_number).to eq '987654321' }
  end

  describe '#consumer_name' do
    it { expect(notice_of_disagreement.consumer_name).to eq 'va.gov' }
  end

  describe '#consumer_id' do
    it { expect(notice_of_disagreement.consumer_id).to eq 'some-guid' }
  end

  describe '#zip_code_5' do
    context 'when address present' do
      before do
        form_data['data']['attributes']['veteran']['address']['zipCode5'] = '30012'
      end

      it { expect(notice_of_disagreement.zip_code_5).to eq '30012' }
    end

    context 'when homeless and no address' do
      before do
        veteran_data = form_data['data']['attributes']['veteran']
        veteran_data['homeless'] = true
        veteran_data.delete('address')
      end

      it { expect(notice_of_disagreement.zip_code_5).to eq '00000' }
    end
  end

  describe '#zip_code_5_or_international_postal_code' do
    it 'returns internationalPostalCode when zip is 0s' do
      expect(notice_of_disagreement.zip_code_5_or_international_postal_code).to eq 'H0H 0H0'
    end

    it 'returns zipCode5 if it is not all 0s' do
      form_data['data']['attributes']['veteran']['address']['zipCode5'] = '30012'
      expect(notice_of_disagreement.zip_code_5_or_international_postal_code).to eq '30012'
    end
  end

  describe '#lob' do
    it { expect(notice_of_disagreement.lob).to eq 'BVA' }
  end

  describe '#board_review_option' do
    it { expect(notice_of_disagreement.board_review_option).to eq 'hearing' }
  end

  describe '#stamp_text' do
    it { expect(notice_of_disagreement.stamp_text).to eq 'Doe - 6789' }
  end

  it_behaves_like 'an appeal model with updatable status' do
    let(:example_instance) { notice_of_disagreement }
    let(:instance_without_email) do
      described_class.create!(
        auth_headers:,
        api_version: 'V1',
        form_data: form_data.deep_merge(
          { 'data' => { 'attributes' => { 'veteran' => { 'emailAddressText' => nil } } } }
        )
      )
    end
  end

  describe 'V2 methods' do
    context 'when validating veteran and non-veteran claimant' do
      let(:nod_with_non_veteran_claimant) { build(:extra_notice_of_disagreement_v2, :board_review_hearing) }

      let(:appeal) { nod_with_non_veteran_claimant }

      it_behaves_like 'shared model validations', validations: %i[veteran_birth_date_is_in_the_past
                                                                  contestable_issue_dates_are_in_the_past
                                                                  required_claimant_data_is_present
                                                                  claimant_birth_date_is_in_the_past],
                                                  required_claimant_headers: described_class.required_nvc_headers

      describe '#veteran' do
        subject { nod_with_non_veteran_claimant.veteran }

        it { expect(subject.class).to eq AppealsApi::Appellant }
      end

      describe '#claimant' do
        subject { nod_with_non_veteran_claimant.claimant }

        it { expect(subject.class).to eq AppealsApi::Appellant }
      end

      describe '#signing_appellant' do
        let(:appellant_type) { nod_with_non_veteran_claimant.signing_appellant.send(:type) }

        it { expect(appellant_type).to eq :claimant }
      end

      describe '#stamp_text' do
        it { expect(nod_with_non_veteran_claimant.stamp_text).to eq 'Doe - 987654321' }
      end

      describe '#appellant_local_time' do
        it do
          nod_with_non_veteran_claimant.save

          appellant_local_time = nod_with_non_veteran_claimant.appellant_local_time
          created_at = nod_with_non_veteran_claimant.created_at

          expect(appellant_local_time).to eq created_at.in_time_zone('America/Chicago')
        end
      end
    end

    context 'when validating form data' do
      let(:extra_notice_of_disagreement_v2) { build(:extra_notice_of_disagreement_v2, :board_review_hearing) }

      describe '#validate_api_version_presence' do
        it 'throws an error when api_version is blank' do
          nod_blank_api_version = FactoryBot.build(:extra_notice_of_disagreement_v2, api_version: '')

          expect(nod_blank_api_version.valid?).to be false
          expect(nod_blank_api_version.errors.size).to eq 1
          expect(nod_blank_api_version.errors.first.message).to include 'api_version attribute'
        end
      end

      describe '#requesting_extension?' do
        it { expect(extra_notice_of_disagreement_v2.requesting_extension?).to eq true }
      end

      describe '#extension_reason' do
        it { expect(extra_notice_of_disagreement_v2.extension_reason).to eq 'good cause substantive reason' }
      end

      describe '#appealing_vha_denial?' do
        it { expect(extra_notice_of_disagreement_v2.appealing_vha_denial?).to eq true }
      end

      describe '#validate_requesting_extension' do
        let(:auth_headers) { fixture_as_json 'valid_10182_headers.json', version: 'v2' }
        let(:form_data) { fixture_as_json 'valid_10182_minimum.json', version: 'v2' }
        let(:invalid_notice_of_disagreement) do
          build(:minimal_notice_of_disagreement_v2, form_data:, auth_headers:, api_version: 'v2')
        end

        context 'when extension reason provided, but extension request is false' do
          before do
            form_data['data']['attributes']['extensionReason'] = 'I need an extension please'

            invalid_notice_of_disagreement.valid?
          end

          it 'throws an error' do
            expect(invalid_notice_of_disagreement.errors.size).to eq 1
            expect(invalid_notice_of_disagreement.errors.first.attribute).to eq(:'/data/attributes/requestingExtension')
            expect(invalid_notice_of_disagreement.errors.first.message).to eq(
              "If '/data/attributes/extensionReason' present, then " \
              "'/data/attributes/requestingExtension' must equal true"
            )
          end
        end
      end
    end
  end
end
