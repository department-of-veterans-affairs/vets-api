# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::NoticeOfDisagreement, type: :model do
  include FixtureHelpers

  shared_examples 'NOD metadata' do |opts|
    let(:nod) { create(opts[:factory]) }

    it 'saves central_mail_business_line to metadata' do
      expect(nod.metadata['central_mail_business_line']).to eq 'BVA'
    end

    describe 'non-veteran claimant flag' do
      it 'saves non-veteran claimant status to metadata' do
        expect(nod.metadata['non_veteran_claimant']).to be(false)
      end

      describe 'with non-veteran claimant' do
        let(:nod) { create(opts[:extra_factory]) }

        it 'saves non-veteran claimant status to metadata' do
          expect(nod.metadata['non_veteran_claimant']).to be(true)
        end
      end
    end

    describe 'potential_write_in_issue_count' do
      context 'with no write-in issues' do
        it 'saves the correct value to metadata' do
          expect(nod.metadata['potential_write_in_issue_count']).to eq(0)
        end
      end

      context 'with write-in issues' do
        let(:form_data) do
          data = fixture_as_json(opts[:form_data_fixture])
          data['included'].push(
            {
              'type' => 'appealableIssue',
              'attributes' => { 'issue' => 'write-in issue text', 'decisionDate' => '1999-09-09' }
            }
          )
          data
        end
        let(:nod) { create(opts[:factory], form_data:) }

        it 'saves the correct value to metadata' do
          expect(nod.metadata['potential_write_in_issue_count']).to eq(1)
        end
      end
    end
  end

  let(:auth_headers) { fixture_as_json 'decision_reviews/v1/valid_10182_headers.json' }
  let(:form_data) { fixture_as_json 'decision_reviews/v1/valid_10182.json' }
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

  describe '#create' do
    let(:nod) do
      bro = form_data['data']['attributes']['boardReviewOption']
      create(:notice_of_disagreement, form_data:, auth_headers:, board_review_option: bro)
    end

    describe 'metadata' do
      # Not using shared examples here because v1 example data is different from v2/v0
      it 'saves consumer benefit type to metadata' do
        expect(nod.metadata['central_mail_business_line']).to eq 'BVA'
      end

      describe 'potential_write_in_issue_count' do
        it 'saves the correct value' do
          expect(nod.metadata['potential_write_in_issue_count']).to eq(3)
        end
      end
    end
  end

  describe 'callbacks' do
    describe 'before_update' do
      before { allow(notice_of_disagreement).to receive(:submit_evidence_to_central_mail!) }

      context 'when the status has changed to "success"' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement, status: 'processing') }

        context 'and the delay evidence feature is enabled' do
          before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'calls "#submit_evidence_to_central_mail!"' do
            notice_of_disagreement.update(status: 'success')

            expect(notice_of_disagreement).to have_received(:submit_evidence_to_central_mail!)
          end
        end

        context 'and the delay evidence feature is disabled' do
          before { Flipper.disable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'does not call "#submit_evidence_to_central_mail!"' do
            notice_of_disagreement.update(status: 'success')

            expect(notice_of_disagreement).not_to have_received(:submit_evidence_to_central_mail!)
          end
        end
      end

      context 'when the status has not changed' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement, status: 'success') }

        context 'and the delay evidence feature is enabled' do
          before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'does not call "#submit_evidence_to_central_mail!"' do
            notice_of_disagreement.update(source: 'VA.gov')

            expect(notice_of_disagreement).not_to have_received(:submit_evidence_to_central_mail!)
          end
        end
      end

      context 'when the status has changed but not to "success"' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement, status: 'submitted') }

        context 'and the delay evidence feature is enabled' do
          before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

          it 'does not call "submit_evidence_to_central_mail!"' do
            notice_of_disagreement.update(status: 'processing')

            expect(notice_of_disagreement).not_to have_received(:submit_evidence_to_central_mail!)
          end
        end
      end
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
      let(:form_data) { fixture_as_json 'decision_reviews/v1/valid_10182_minimum.json' }

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

  describe '#veteran_birth_date' do
    it { expect(notice_of_disagreement.veteran_birth_date&.iso8601).to eq '1969-12-31' }
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

  describe '#submit_evidence_to_central_mail!' do
    let(:notice_of_disagreement) { create(:notice_of_disagreement) }
    let(:evidence_submission1) { create(:evidence_submission, supportable: notice_of_disagreement) }
    let(:evidence_submission2) { create(:evidence_submission, supportable: notice_of_disagreement) }
    let(:evidence_submissions) { [evidence_submission1, evidence_submission2] }

    before do
      allow(notice_of_disagreement).to receive(:evidence_submissions).and_return(evidence_submissions)
      allow(evidence_submission1).to receive(:submit_to_central_mail!)
      allow(evidence_submission2).to receive(:submit_to_central_mail!)
    end

    it 'calls "#submit_to_central_mail!" for each evidence submission' do
      notice_of_disagreement.submit_evidence_to_central_mail!

      expect(evidence_submission1).to have_received(:submit_to_central_mail!)
      expect(evidence_submission2).to have_received(:submit_to_central_mail!)
    end
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
                                                                  claimant_birth_date_is_in_the_past
                                                                  country_codes_valid],
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
          nod_blank_api_version = build(:extra_notice_of_disagreement_v2, api_version: '')

          expect(nod_blank_api_version.valid?).to be false
          expect(nod_blank_api_version.errors.size).to eq 1
          expect(nod_blank_api_version.errors.first.message).to include 'api_version attribute'
        end
      end

      describe '#requesting_extension?' do
        it { expect(extra_notice_of_disagreement_v2.requesting_extension?).to be true }
      end

      describe '#extension_reason' do
        it { expect(extra_notice_of_disagreement_v2.extension_reason).to eq 'good cause substantive reason' }
      end

      describe '#appealing_vha_denial?' do
        it { expect(extra_notice_of_disagreement_v2.appealing_vha_denial?).to be true }
      end

      describe '#validate_requesting_extension' do
        let(:auth_headers) { fixture_as_json 'decision_reviews/v2/valid_10182_headers.json' }
        let(:form_data) { fixture_as_json 'decision_reviews/v2/valid_10182_minimum.json' }
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

    describe 'metadata' do
      include_examples 'NOD metadata', {
        factory: :notice_of_disagreement_v2,
        extra_factory: :extra_notice_of_disagreement_v2,
        form_data_fixture: 'decision_reviews/v2/valid_10182.json'
      }
    end

    describe '#veteran_icn' do
      subject { nod.veteran_icn }

      let(:nod) { create(:extra_notice_of_disagreement_v2) }

      it 'matches header' do
        expect(subject).to be_present
        expect(subject).to eq nod.auth_headers['X-VA-ICN']
      end

      describe 'when ICN not provided in header' do
        let(:nod) { create(:notice_of_disagreement_v2) }

        it 'is blank' do
          expect(subject).to be_blank
        end
      end
    end
  end

  describe 'when api_version is V0' do
    let(:appeal) { create(:extra_notice_of_disagreement_v0, api_version: 'V0') }

    describe '#veteran_icn' do
      subject { appeal.veteran_icn }

      it 'matches the ICN in the form data' do
        expect(subject).to be_present
        expect(subject).to eq appeal.form_data.dig('data', 'attributes', 'veteran', 'icn')
      end
    end

    it_behaves_like 'shared model validations',
                    required_claimant_headers: [],
                    validations: %i[veteran_birth_date_is_in_the_past
                                    contestable_issue_dates_are_in_the_past
                                    claimant_birth_date_is_in_the_past
                                    country_codes_valid]

    describe 'metadata' do
      include_examples 'NOD metadata', {
        factory: :notice_of_disagreement_v0,
        extra_factory: :extra_notice_of_disagreement_v0,
        form_data_fixture: 'notice_of_disagreements/v0/valid_10182.json'
      }
    end
  end
end
