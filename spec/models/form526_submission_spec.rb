# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe Form526Submission do
  subject do
    Form526Submission.create(
      user_uuid: user.uuid,
      saved_claim_id: saved_claim.id,
      auth_headers_json: auth_headers.to_json,
      form_json:,
      submit_endpoint:,
      backup_submitted_claim_status:
    )
  end

  let(:user) { create(:user, :loa3, first_name: 'Beyonce', last_name: 'Knowles') }
  let(:user_account) { create(:user_account, icn: user.icn, id: user.user_account_uuid) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:saved_claim) { FactoryBot.create(:va526ez) }
  let(:form_json) do
    File.read('spec/support/disability_compensation_form/submissions/only_526.json')
  end
  let(:submit_endpoint) { nil }
  let(:backup_submitted_claim_status) { nil }

  before do
    Flipper.disable(:disability_compensation_production_tester)
  end

  describe 'associations' do
    it { is_expected.to have_many(:form526_submission_remediations) }
  end

  describe 'submit_endpoint enum' do
    context 'when submit_endpoint is evss' do
      let(:submit_endpoint) { 'evss' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when submit_endpoint is claims_api' do
      let(:submit_endpoint) { 'claims_api' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when submit_endpoint is benefits_intake_api' do
      let(:submit_endpoint) { 'benefits_intake_api' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when submit_endpoint is not evss, claims_api or benefits_intake_api' do
      it 'is invalid' do
        expect do
          subject.submit_endpoint = 'other_value'
        end.to raise_error(ArgumentError, "'other_value' is not a valid submit_endpoint")
      end
    end
  end

  describe 'backup_submitted_claim_status enum' do
    context 'when backup_submitted_claim_status is nil' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when backup_submitted_claim_status is accepted' do
      let(:backup_submitted_claim_status) { 'accepted' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when backup_submitted_claim_status is rejected' do
      let(:backup_submitted_claim_status) { 'rejected' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when backup_submitted_claim_status is paranoid_success' do
      let(:backup_submitted_claim_status) { 'paranoid_success' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when backup_submitted_claim_status is neither accepted, rejected nor nil' do
      it 'is invalid' do
        expect do
          subject.backup_submitted_claim_status = 'other_value'
        end.to raise_error(ArgumentError, "'other_value' is not a valid backup_submitted_claim_status")
      end
    end
  end

  describe 'scopes' do
    let!(:in_process) { create(:form526_submission) }
    let!(:expired) { create(:form526_submission, :created_more_than_3_weeks_ago) }
    let!(:happy_path_success) { create(:form526_submission, :with_submitted_claim_id) }
    let!(:pending_backup) { create(:form526_submission, :backup_path) }
    let!(:accepted_backup) { create(:form526_submission, :backup_path, :backup_accepted) }
    let!(:rejected_backup) { create(:form526_submission, :backup_path, :backup_rejected) }
    let!(:remediated) { create(:form526_submission, :remediated) }
    let!(:remediated_and_expired) { create(:form526_submission, :remediated, :created_more_than_3_weeks_ago) }
    let!(:remediated_and_rejected) { create(:form526_submission, :remediated, :backup_path, :backup_rejected) }
    let!(:no_longer_remediated) { create(:form526_submission, :no_longer_remediated) }
    let!(:paranoid_success) { create(:form526_submission, :backup_path, :paranoid_success) }
    let!(:success_by_age) do
      Timecop.freeze((1.year + 1.day).ago) do
        create(:form526_submission, :backup_path, :paranoid_success)
      end
    end

    describe 'paranoid_success_type' do
      it 'returns records less than a year old with paranoid_success backup status' do
        expect(Form526Submission.paranoid_success_type).to contain_exactly(
          paranoid_success
        )
      end
    end

    describe 'success_by_age_type' do
      it 'returns records more than a year old with paranoid_success backup status' do
        expect(Form526Submission.success_by_age_type).to contain_exactly(
          success_by_age
        )
      end
    end

    describe 'pending_backup_submissions' do
      it 'returns records submitted to the backup path but lacking a decisive state' do
        expect(Form526Submission.pending_backup_submissions).to contain_exactly(
          pending_backup
        )
      end
    end

    describe 'in_process' do
      it 'only returns submissions that are still in process' do
        expect(Form526Submission.in_process).to contain_exactly(
          in_process,
          pending_backup
        )
      end
    end

    describe 'accepted_to_primary_path' do
      it 'returns submissions with a submitted_claim_id' do
        expect(Form526Submission.accepted_to_primary_path).to contain_exactly(
          happy_path_success
        )
      end
    end

    describe 'accepted_to_backup_path' do
      it 'returns submissions with a backup_submitted_claim_id that have been explicitly accepted' do
        expect(Form526Submission.accepted_to_backup_path).to contain_exactly(
          accepted_backup
        )
      end
    end

    describe 'rejected_from_backup_path' do
      it 'returns submissions with a backup_submitted_claim_id that have been explicitly rejected' do
        expect(Form526Submission.rejected_from_backup_path).to contain_exactly(
          rejected_backup,
          remediated_and_rejected
        )
      end
    end

    describe 'remediated' do
      it 'returns everything with a successful remediation' do
        expect(Form526Submission.remediated).to contain_exactly(
          remediated,
          remediated_and_expired,
          remediated_and_rejected
        )
      end
    end

    describe 'success_type' do
      it 'returns all submissions on which no further action is required' do
        expect(Form526Submission.success_type).to contain_exactly(
          remediated,
          remediated_and_expired,
          remediated_and_rejected,
          happy_path_success,
          accepted_backup,
          paranoid_success,
          success_by_age
        )
      end
    end

    describe 'failure_type' do
      it 'returns anything not explicitly successful or still in process' do
        expect(Form526Submission.failure_type).to contain_exactly(
          rejected_backup,
          no_longer_remediated,
          expired
        )
      end
    end
  end

  shared_examples '#start_evss_submission' do
    context 'when it is all claims' do
      it 'queues an all claims job' do
        expect do
          subject.start_evss_submission_job
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(1)
      end
    end
  end

  describe '#start' do
    context 'the submission is for hypertension' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/only_526_hypertension.json')
      end

      it_behaves_like '#start_evss_submission'
    end

    context 'the submission is NOT for hypertension' do
      it_behaves_like '#start_evss_submission'
    end

    context 'CFI metric logging' do
      let!(:in_progress_form) do
        ipf = create(:in_progress_526_form, user_uuid: user.uuid)
        fd = ipf.form_data
        fd = JSON.parse(fd)
        fd['rated_disabilities'] = rated_disabilities
        ipf.update!(form_data: fd)
        ipf
      end

      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
        Flipper.disable(:disability_526_maximum_rating)
      end

      def expect_max_cfi_logged(max_cfi_enabled, disability_claimed, diagnostic_code, total_increase_conditions)
        expect(Rails.logger).to have_received(:info).with(
          'Max CFI form526 submission',
          { id: subject.id, max_cfi_enabled:, disability_claimed:, diagnostic_code:, total_increase_conditions:,
            cfi_checkbox_was_selected: false }
        )
      end

      context 'the submission is for tinnitus' do
        let(:form_json) do
          File.read('spec/support/disability_compensation_form/submissions/only_526_tinnitus.json')
        end
        let(:rated_disabilities) do
          [
            { name: 'Tinnitus',
              diagnostic_code: ClaimFastTracking::DiagnosticCodes::TINNITUS,
              rating_percentage:,
              maximum_rating_percentage: 10 }
          ]
        end
        let(:rating_percentage) { 0 }

        context 'Max rating education enabled' do
          before { Flipper.enable(:disability_526_maximum_rating, user) }

          context 'Rated Tinnitus is at maximum' do
            let(:rating_percentage) { 10 }

            it 'logs CFI metric upon submission' do
              subject.start
              expect(StatsD).to have_received(:increment).with('api.max_cfi.on.submit.6260')
              expect_max_cfi_logged('on', true, 6260, 1)
            end
          end

          context 'Rated Tinnitus is not at maximum' do
            it 'does not log CFI metric upon submission' do
              subject.start
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.6260')
            end
          end
        end

        context 'Max rating education disabled' do
          before { Flipper.disable(:disability_526_maximum_rating, user) }

          context 'Rated Tinnitus is at maximum' do
            let(:rating_percentage) { 10 }

            it 'logs CFI metric upon submission' do
              subject.start
              expect(StatsD).to have_received(:increment).with('api.max_cfi.off.submit.6260')
              expect_max_cfi_logged('off', true, 6260, 1)
            end
          end

          context 'Rated Tinnitus is not at maximum' do
            it 'does not log CFI metric upon submission' do
              subject.start
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.6260')
            end
          end
        end
      end

      context 'the submission is for hypertension with no max rating percentage' do
        let(:form_json) do
          File.read('spec/support/disability_compensation_form/submissions/only_526_hypertension.json')
        end
        let(:rated_disabilities) do
          [
            { name: 'Hypertension',
              diagnostic_code: ClaimFastTracking::DiagnosticCodes::HYPERTENSION,
              rating_percentage: 20 }
          ]
        end

        context 'Max rating education enabled' do
          before { Flipper.enable(:disability_526_maximum_rating, user) }

          it 'does not log CFI metric upon submission' do
            subject.start
            expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.7101')
          end
        end

        context 'Max rating education disabled' do
          before { Flipper.disable(:disability_526_maximum_rating, user) }

          it 'does not log CFI metric upon submission' do
            subject.start
            expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.7101')
          end
        end
      end

      context 'the submission is from a Veteran with rated tinnitus and hypertension' do
        let(:form_json) do
          File.read('spec/support/disability_compensation_form/submissions/only_526_two_cfi_with_max_ratings.json')
        end
        let(:rated_disabilities) do
          [
            { name: 'Tinnitus',
              diagnostic_code: ClaimFastTracking::DiagnosticCodes::TINNITUS,
              rating_percentage: rating_percentage_tinnitus,
              maximum_rating_percentage: 10 },
            { name: 'Hypertension',
              diagnostic_code: ClaimFastTracking::DiagnosticCodes::HYPERTENSION,
              rating_percentage: rating_percentage_hypertension,
              maximum_rating_percentage: 60 }
          ]
        end
        let(:rating_percentage_tinnitus) { 0 }
        let(:rating_percentage_hypertension) { 0 }

        context 'Max rating education enabled' do
          before { Flipper.enable(:disability_526_maximum_rating, user) }

          context 'Rated Disabilities are not at maximum' do
            it 'does not log CFI metric upon submission' do
              subject.start
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.7101')
            end
          end

          context 'Rated Disabilities are at maximum' do
            let(:rating_percentage_tinnitus) { 10 }
            let(:rating_percentage_hypertension) { 60 }

            it 'logs CFI metric upon submission only for tinnitus' do
              subject.start
              expect(StatsD).to have_received(:increment).with('api.max_cfi.on.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.7101')
              expect_max_cfi_logged('on', true, 6260, 2)
            end

            context 'when the submission omits tinnitus' do
              let(:form_json) do
                File.read('spec/support/disability_compensation_form/submissions/only_526_hypertension.json')
              end

              it 'logs CFI metric upon submission for tinnitus being omitted' do
                subject.start
                expect_max_cfi_logged('on', false, 6260, 1)
              end
            end
          end

          context 'Only Tinnitus is rated at the maximum' do
            let(:rating_percentage_tinnitus) { 10 }

            it 'logs CFI metric upon submission only for tinnitus' do
              subject.start
              expect(StatsD).to have_received(:increment).with('api.max_cfi.on.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.7101')
              expect_max_cfi_logged('on', true, 6260, 2)
            end
          end

          context 'Only Hypertension is rated at the maximum' do
            let(:rating_percentage_hypertension) { 60 }

            it 'does not log CFI metric upon submission' do
              subject.start
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.on.submit.7101')
            end
          end
        end

        context 'Max rating education disabled' do
          before { Flipper.disable(:disability_526_maximum_rating, user) }

          context 'Rated Disabilities are not at maximum' do
            it 'does not log CFI metric upon submission' do
              subject.start
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.7101')
            end
          end

          context 'Rated Disabilities are at maximum' do
            let(:rating_percentage_tinnitus) { 10 }
            let(:rating_percentage_hypertension) { 60 }

            it 'logs CFI metric upon submission only for tinnitus' do
              subject.start
              expect(StatsD).to have_received(:increment).with('api.max_cfi.off.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.7101')
              expect_max_cfi_logged('off', true, 6260, 2)
            end
          end

          context 'Only Tinnitus is rated at the maximum' do
            let(:rating_percentage_tinnitus) { 10 }

            it 'logs CFI metric upon submission only for tinnitus' do
              subject.start
              expect(StatsD).to have_received(:increment).with('api.max_cfi.off.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.7101')
              expect_max_cfi_logged('off', true, 6260, 2)
            end
          end

          context 'Only Hypertension is rated at the maximum' do
            let(:rating_percentage_hypertension) { 60 }

            it 'does not log CFI metric upon submission' do
              subject.start
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.6260')
              expect(StatsD).not_to have_received(:increment).with('api.max_cfi.off.submit.7101')
            end
          end
        end
      end
    end
  end

  describe '#start_evss_submission_job' do
    it_behaves_like '#start_evss_submission'
  end

  describe '#submit_with_birls_id_that_hasnt_been_tried_yet!' do
    context 'when it is all claims' do
      it 'queues an all claims job' do
        expect(subject.birls_id).to be_truthy
        expect(subject.birls_ids.count).to eq 1
        subject.birls_ids_tried = { subject.birls_id => ['some timestamp'] }.to_json
        subject.save!
        expect { subject.submit_with_birls_id_that_hasnt_been_tried_yet! }.to(
          change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(0)
        )
        next_birls_id = "#{subject.birls_id}cat"
        subject.add_birls_ids next_birls_id
        expect { subject.submit_with_birls_id_that_hasnt_been_tried_yet! }.to(
          change(EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.jobs, :size).by(1)
        )
        expect(subject.birls_id).to eq next_birls_id
      end
    end
  end

  describe '#form' do
    it 'returns the form as a hash' do
      expect(subject.form).to eq(JSON.parse(form_json))
    end
  end

  describe '#form_to_json' do
    context 'with form 526' do
      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_526)).to eq(JSON.parse(form_json)['form526'].to_json)
      end
    end

    context 'with form 4142' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end

      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_4142)).to eq(JSON.parse(form_json)['form4142'].to_json)
      end
    end

    context 'with form 0781' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_0781.json')
      end

      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_0781)).to eq(JSON.parse(form_json)['form0781'].to_json)
      end
    end

    context 'with form 8940' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_8940.json')
      end

      it 'returns the sub form as json' do
        expect(subject.form_to_json(Form526Submission::FORM_8940)).to eq(JSON.parse(form_json)['form8940'].to_json)
      end
    end
  end

  describe '#auth_headers' do
    it 'returns the parsed auth headers' do
      expect(subject.auth_headers).to eq(auth_headers)
    end
  end

  describe '#add_birls_ids' do
    subject do
      headers = JSON.parse auth_headers.to_json
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    context 'birls_ids_tried nil' do
      let(:birls_ids_tried) { nil }

      it 'has no default' do
        expect(subject.birls_ids_tried).to eq 'null'
      end

      context 'using nil as an id' do
        it 'results in an empty hash' do
          subject.add_birls_ids nil
          expect(JSON.parse(subject.birls_ids_tried)).to be_a Hash
        end
      end

      context 'single id' do
        it 'initializes with an empty array' do
          subject.add_birls_ids 'a'
          expect(subject.birls_ids_tried_hash).to eq 'a' => []
        end
      end

      context 'an array of ids' do
        it 'initializes with an empty arrays' do
          subject.add_birls_ids(%w[a b c])
          expect(subject.birls_ids_tried_hash).to eq 'a' => [], 'b' => [], 'c' => []
        end
      end
    end

    context 'birls_ids_tried already has values' do
      let(:birls_ids_tried) { { 'a' => ['2021-02-01T14:28:33Z'] } }

      context 'using nil as an id' do
        it 'results in an empty hash' do
          subject.add_birls_ids nil
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried
        end
      end

      context 'single id that is already present' do
        it 'does nothing' do
          subject.add_birls_ids 'a'
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried
        end
      end

      context 'single id that is not already present' do
        it 'does nothing' do
          subject.add_birls_ids 'b'
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried.merge('b' => [])
        end
      end

      context 'an array of ids' do
        it 'initializes with an empty arrays, for ids that area not already present' do
          subject.add_birls_ids(['a', :b, :c])
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried.merge('b' => [], 'c' => [])
        end
      end

      context 'an array of ids persisted' do
        it 'persists' do
          subject.add_birls_ids(['a', :b, :c])
          subject.save
          subject.reload
          expect(subject.birls_ids_tried_hash).to eq birls_ids_tried.merge('b' => [], 'c' => [])
        end
      end
    end
  end

  describe '#birls_ids' do
    subject do
      headers = JSON.parse auth_headers.to_json
      headers['va_eauth_birlsfilenumber'] = birls_id
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    let(:birls_id) { 'a' }
    let(:birls_ids_tried) { { b: [], c: ['2021-02-01T14:28:33Z'] } }

    context 'birls_ids_tried present and auth_headers present' do
      it 'lists all birls ids' do
        expect(subject.birls_ids).to contain_exactly 'c', 'b', 'a'
      end

      it 'persists' do
        subject.save
        subject.reload
        expect(subject.birls_ids).to contain_exactly 'b', 'c', 'a'
      end
    end

    context 'only birls_ids_tried present' do
      subject do
        Form526Submission.new(
          user_uuid: user.uuid,
          saved_claim_id: saved_claim.id,
          form_json:,
          birls_ids_tried: birls_ids_tried.to_json
        )
      end

      it 'lists birls ids from birls_ids_tried only' do
        expect(subject.birls_ids).to contain_exactly 'b', 'c'
      end
    end

    context 'only auth_headers present' do
      let(:birls_ids_tried) { nil }

      it 'lists birls ids from auth_headers only' do
        expect(subject.birls_ids).to contain_exactly 'a'
      end
    end
  end

  describe '#mark_birls_id_as_tried' do
    subject do
      headers = JSON.parse auth_headers.to_json
      headers['va_eauth_birlsfilenumber'] = birls_id
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    let(:birls_id) { 'a' }

    context 'nil birls_ids_tried' do
      let(:birls_ids_tried) { nil }

      it 'adds the current birls id to birls_ids_tried' do
        expect(JSON.parse(subject.birls_ids_tried)).to eq birls_ids_tried
        subject.mark_birls_id_as_tried
        expect(subject.birls_ids_tried_hash.keys).to contain_exactly 'a'
        subject.save
        subject.reload
        expect(subject.birls_ids_tried_hash.keys).to contain_exactly 'a'
      end
    end

    context 'previous attempts' do
      let(:birls_ids_tried) { { 'b' => ['2021-02-01T14:28:33Z'] } }

      it 'adds the current BIRLS ID to birls_ids_tried array (turns birls_ids_tried into an array if nil)' do
        expect(JSON.parse(subject.birls_ids_tried)).to eq birls_ids_tried
        subject.mark_birls_id_as_tried
        expect(subject.birls_ids_tried_hash.keys).to contain_exactly(birls_id, *birls_ids_tried.keys)
        subject.save
        subject.reload
        expect(subject.birls_ids_tried_hash.keys).to contain_exactly(birls_id, *birls_ids_tried.keys)
      end
    end
  end

  describe '#birls_ids_that_havent_been_tried_yet' do
    subject do
      headers = JSON.parse auth_headers.to_json
      headers['va_eauth_birlsfilenumber'] = birls_id
      Form526Submission.new(
        user_uuid: user.uuid,
        saved_claim_id: saved_claim.id,
        auth_headers_json: headers.to_json,
        form_json:,
        birls_ids_tried: birls_ids_tried.to_json
      )
    end

    let(:birls_id) { 'a' }
    let(:birls_ids_tried) { { b: [], c: ['2021-02-01T14:28:33Z'], d: nil } }

    it 'does not include birls ids that have already been tried' do
      expect(subject.birls_ids_that_havent_been_tried_yet).to contain_exactly('a', 'b', 'd')
    end
  end

  describe '#birls_id!' do
    it 'returns the BIRLS ID' do
      expect(subject.birls_id!).to eq(auth_headers[described_class::BIRLS_KEY])
    end

    context 'auth_headers is nil' do
      it 'throws an exception' do
        subject.auth_headers_json = nil
        expect { subject.birls_id! }.to raise_error TypeError
      end
    end

    context 'auth_headers is unparseable' do
      it 'throws an exception' do
        subject.auth_headers_json = 'hi!'
        expect { subject.birls_id! }.to raise_error JSON::ParserError
      end
    end
  end

  describe '#birls_id' do
    it 'returns the BIRLS ID' do
      expect(subject.birls_id).to eq(auth_headers[described_class::BIRLS_KEY])
    end

    context 'auth_headers is nil' do
      it 'returns nil' do
        subject.auth_headers_json = nil
        expect(subject.birls_id).to be_nil
      end
    end

    context 'auth_headers is unparseable' do
      it 'throws an exception' do
        subject.auth_headers_json = 'hi!'
        expect { subject.birls_id }.to raise_error JSON::ParserError
      end
    end
  end

  describe '#birls_id=' do
    let(:birls_id) { 1 }

    it 'sets the BIRLS ID' do
      subject.birls_id = birls_id
      expect(subject.birls_id).to eq(birls_id)
    end

    context 'auth_headers is nil' do
      it 'throws an exception' do
        subject.auth_headers_json = nil
        expect { subject.birls_id = birls_id }.to raise_error TypeError
      end
    end

    context 'auth_headers is unparseable' do
      it 'throws an exception' do
        subject.auth_headers_json = 'hi!'
        expect { subject.birls_id = birls_id }.to raise_error JSON::ParserError
      end
    end
  end

  describe '#perform_ancillary_jobs_handler' do
    let(:status) { OpenStruct.new(parent_bid: SecureRandom.hex(8)) }

    context 'with an ancillary job' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 3 jobs' do
        subject.form526_job_statuses <<
          Form526JobStatus.new(job_class: 'SubmitForm526AllClaim', status: 'success', job_id: 0)
        expect do
          subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(3)
      end

      it 'warns when there are multiple successful submit526 jobs' do
        2.times do |index|
          subject.form526_job_statuses << Form526JobStatus.new(
            job_class: 'SubmitForm526AllClaim',
            status: Form526JobStatus::STATUS[:success],
            job_id: index
          )
        end
        expect(Form526JobStatus.all.count).to eq 2
        expect_any_instance_of(Form526Submission).to receive(:log_message_to_sentry).with(
          'There are multiple successful SubmitForm526 job statuses',
          :warn,
          { form_526_submission_id: subject.id }
        )
        subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
      end

      it "warns when there's a successful submit526 job, but it's not the most recent submit526 job" do
        %i[success retryable_error].each_with_index do |status, index|
          subject.form526_job_statuses << Form526JobStatus.new(
            job_class: 'SubmitForm526AllClaim',
            status: Form526JobStatus::STATUS[status],
            job_id: index,
            updated_at: Time.zone.now + index.days
          )
        end
        expect(Form526JobStatus.all.count).to eq 2
        expect_any_instance_of(Form526Submission).to receive(:log_message_to_sentry).with(
          "There is a successful SubmitForm526 job, but it's not the most recent SubmitForm526 job",
          :warn,
          { form_526_submission_id: subject.id }
        )
        subject.perform_ancillary_jobs_handler(status, 'submission_id' => subject.id)
      end
    end
  end

  describe '#perform_ancillary_jobs' do
    let(:first_name) { 'firstname' }

    context 'with (3) uploads' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      it 'queues 3 upload jobs' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::SubmitUploads.jobs, :size).by(3)
      end
    end

    context 'with flashes' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      context 'when feature enabled' do
        before { Flipper.enable(:disability_compensation_flashes) }

        it 'queues flashes job' do
          expect do
            subject.perform_ancillary_jobs(first_name)
          end.to change(BGS::FlashUpdater.jobs, :size).by(1)
        end
      end

      context 'when feature disabled' do
        before { Flipper.disable(:disability_compensation_flashes) }

        it 'queues flashes job' do
          expect do
            subject.perform_ancillary_jobs(first_name)
          end.to change(BGS::FlashUpdater.jobs, :size).by(0)
        end
      end
    end

    context 'BDD' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/526_bdd.json')
      end

      it 'queues 1 UploadBddInstructions job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::UploadBddInstructions.jobs, :size).by(1)
      end
    end

    context 'with form 4142' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
      end

      it 'queues a 4142 job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(CentralMail::SubmitForm4142Job.jobs, :size).by(1)
      end
    end

    context 'with form 0781' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_0781.json')
      end

      it 'queues a 0781 job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm0781.jobs, :size).by(1)
      end
    end

    context 'with form 8940' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_8940.json')
      end

      it 'queues a 8940 job' do
        expect do
          subject.perform_ancillary_jobs(first_name)
        end.to change(EVSS::DisabilityCompensationForm::SubmitForm8940.jobs, :size).by(1)
      end
    end

    context 'with Lighthouse document upload polling' do
      let(:form_json) do
        File.read('spec/support/disability_compensation_form/submissions/with_uploads.json')
      end

      context 'when feature enabled' do
        before { Flipper.enable(:disability_526_toxic_exposure_document_upload_polling) }

        it 'queues polling job' do
          expect do
            form = subject.saved_claim.parsed_form
            form['startedFormVersion'] = '2022'
            subject.update(submitted_claim_id: 1)
            subject.saved_claim.update(form: form.to_json)
            subject.perform_ancillary_jobs(first_name)
          end.to change(Lighthouse::PollForm526Pdf.jobs, :size).by(1)
        end
      end

      context 'when feature disabled' do
        before { Flipper.disable(:disability_526_toxic_exposure_document_upload_polling) }

        it 'does not queue polling job' do
          expect do
            subject.perform_ancillary_jobs(first_name)
          end.to change(Lighthouse::PollForm526Pdf.jobs, :size).by(0)
        end
      end
    end
  end

  describe '#get_first_name' do
    [
      {
        input: 'Joe',
        expected: 'JOE'
      },
      {
        input: 'JOE',
        expected: 'JOE'
      }, {
        input: 'joe mark',
        expected: 'JOE MARK'
      }
    ].each do |test_param|
      it 'gets correct first name' do
        allow(User).to receive(:find).with(anything).and_return(user)
        allow_any_instance_of(User).to receive(:first_name).and_return(test_param[:input])

        expect(subject.get_first_name).to eql(test_param[:expected])
      end
    end

    context 'when the first name is NOT populated on the User' do
      before do
        # Ensure `subject` is called before stubbing `first_name` so that the auth headers are populated correctly
        subject
        user_with_nil_first_name = User.create(user)
        allow(user_with_nil_first_name).to receive(:first_name).and_return nil
        allow(User).to receive(:find).with(subject.user_uuid).and_return user_with_nil_first_name
      end

      context 'when name attributes exist in the auth headers' do
        it 'returns the first name of the user from the auth headers' do
          expect(subject.get_first_name).to eql('BEYONCE')
        end
      end

      context 'when name attributes do NOT exist in the auth headers' do
        subject { build(:form526_submission, :with_empty_auth_headers) }

        it 'returns nil' do
          expect(subject.get_first_name).to be nil
        end
      end
    end

    context 'when the User is NOT found' do
      before { allow(User).to receive(:find).and_return nil }

      it 'returns the first name of the user from the auth headers' do
        expect(subject.get_first_name).to eql('BEYONCE')
      end
    end
  end

  describe '#full_name' do
    let(:full_name_hash) do
      {
        first: 'Beyonce',
        middle: nil,
        last: 'Knowles',
        suffix: user.normalized_suffix
      }
    end

    context 'when the full name exists on the User' do
      it 'returns the full name of the user' do
        expect(subject.full_name).to eql(full_name_hash)
      end
    end

    context 'when the full name is NOT populated on the User but name attributes exist in the auth_headers' do
      let(:nil_full_name_hash) do
        {
          first: nil,
          middle: nil,
          last: nil,
          suffix: nil
        }
      end

      before do
        allow_any_instance_of(User).to receive(:full_name_normalized).and_return nil_full_name_hash
      end

      context 'when name attributes exist in the auth headers' do
        it 'returns the first and last name of the user from the auth headers' do
          expect(subject.full_name).to eql(full_name_hash.merge(middle: nil, suffix: nil))
        end
      end

      context 'when name attributes do NOT exist in the auth headers' do
        subject { build(:form526_submission, :with_empty_auth_headers) }

        it 'returns the hash with all nil values' do
          expect(subject.full_name).to eql nil_full_name_hash
        end
      end
    end

    context 'when the User is NOT found' do
      before { allow(User).to receive(:find).and_return nil }

      it 'returns the first and last name of the user from the auth headers' do
        expect(subject.full_name).to eql(full_name_hash.merge(middle: nil, suffix: nil))
      end
    end
  end

  describe '#workflow_complete_handler' do
    describe 'success' do
      let(:options) do
        {
          'submission_id' => subject.id,
          'first_name' => 'firstname'
        }
      end

      context 'with a single successful job' do
        subject { create(:form526_submission, :with_one_succesful_job) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_truthy
        end
      end

      context 'with multiple successful jobs' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_truthy
        end
      end

      context 'with multiple successful jobs and email and submitted time in PM' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

        before { Timecop.freeze(Time.zone.parse('2012-07-20 14:15:00 UTC')) }

        after { Timecop.return }

        it 'calls confirmation email job with correct personalization' do
          allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
            expect(args[0]['first_name']).to eql('firstname')
            expect(args[0]['submitted_claim_id']).to be(123_654_879)
            expect(args[0]['email']).to eql('test@email.com')
            expect(args[0]['date_submitted']).to eql('July 20, 2012 2:15 p.m. UTC')
          end

          subject.workflow_complete_handler(nil, options)
        end
      end

      context 'with multiple successful jobs and email and submitted time in PM with two digit hour' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

        before { Timecop.freeze(Time.zone.parse('2012-07-20 11:12:00 UTC')) }

        after { Timecop.return }

        it 'calls confirmation email job with correct personalization' do
          allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
            expect(args[0]['first_name']).to eql('firstname')
            expect(args[0]['submitted_claim_id']).to be(123_654_879)
            expect(args[0]['email']).to eql('test@email.com')
            expect(args[0]['date_submitted']).to eql('July 20, 2012 11:12 a.m. UTC')
          end

          subject.workflow_complete_handler(nil, options)
        end
      end

      context 'with multiple successful jobs and email and submitted time in morning' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs, submitted_claim_id: 123_654_879) }

        before { Timecop.freeze(Time.zone.parse('2012-07-20 8:07:00 UTC')) }

        after { Timecop.return }

        it 'calls confirmation email job with correct personalization' do
          allow(Form526ConfirmationEmailJob).to receive(:perform_async) do |*args|
            expect(args[0]['first_name']).to eql('firstname')
            expect(args[0]['submitted_claim_id']).to be(123_654_879)
            expect(args[0]['email']).to eql('test@email.com')
            expect(args[0]['date_submitted']).to eql('July 20, 2012 8:07 a.m. UTC')
          end

          subject.workflow_complete_handler(nil, options)
        end
      end

      context 'with submission confirmation email when successful job statuses' do
        subject { create(:form526_submission, :with_multiple_succesful_jobs) }

        it 'returns one job triggered' do
          expect do
            subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          end.to change(Form526ConfirmationEmailJob.jobs, :size).by(1)
        end
      end
    end

    describe 'failure' do
      context 'with mixed result jobs' do
        subject { create(:form526_submission, :with_mixed_status) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_falsey
        end
      end

      context 'with a failing 526 form job' do
        subject { create(:form526_submission, :with_one_failed_job) }

        it 'sets the submission.complete to true' do
          expect(subject.workflow_complete).to be_falsey
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          subject.reload
          expect(subject.workflow_complete).to be_falsey
        end
      end

      context 'with submission confirmation email when failed job statuses' do
        subject { create(:form526_submission, :with_mixed_status) }

        it 'returns zero jobs triggered' do
          expect do
            subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
          end.to change(Form526ConfirmationEmailJob.jobs, :size).by(0)
        end
      end

      it 'sends a submission failed email notification' do
        expect do
          subject.workflow_complete_handler(nil, 'submission_id' => subject.id)
        end.to change(Form526SubmissionFailedEmailJob.jobs, :size).by(1)
      end
    end
  end

  describe '#disabilities_not_service_connected?' do
    subject { form_526_submission.disabilities_not_service_connected? }

    before { create(:idme_user_verification, idme_uuid: user.idme_uuid, user_account:) }

    let(:form_526_submission) do
      Form526Submission.create(
        user_uuid: user.uuid,
        user_account: user.user_account,
        saved_claim_id: saved_claim.id,
        auth_headers_json: auth_headers.to_json,
        form_json: File.read("spec/support/disability_compensation_form/submissions/#{form_json_filename}")
      )
    end

    context 'evss provider' do
      before { VCR.insert_cassette('evss/disability_compensation_form/rated_disabilities_with_non_service_connected') }
      after { VCR.eject_cassette('evss/disability_compensation_form/rated_disabilities_with_non_service_connected') }

      context 'when all corresponding rated disabilities are not service-connected' do
        Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND)
        let(:form_json_filename) { 'only_526_asthma.json' }

        it 'returns true' do
          expect(subject).to be_truthy
        end
      end

      context 'when some but not all corresponding rated disabilities are not service-connected' do
        Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND)
        let(:form_json_filename) { 'only_526_two_rated_disabilities.json' }

        it 'returns false' do
          expect(subject).to be_falsey
        end
      end

      context 'when some disabilities do not have a ratedDisabilityId yet' do
        Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND)
        let(:form_json_filename) { 'only_526_mixed_action_disabilities.json' }

        it 'returns false' do
          expect(subject).to be_falsey
        end
      end
    end

    context 'Lighthouse provider' do
      before do
        Flipper.enable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND)
        VCR.insert_cassette('lighthouse/veteran_verification/disability_rating/200_Not_Connected_response')
        allow_any_instance_of(Auth::ClientCredentials::Service).to receive(:get_token).and_return('blahblech')
      end

      after do
        Flipper.disable(ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_BACKGROUND)
        VCR.eject_cassette('lighthouse/veteran_verification/disability_rating/200_Not_Connected_response')
      end

      context 'when all corresponding rated disabilities are not service-connected' do
        let(:form_json_filename) { 'only_526_asthma.json' }

        it 'returns true' do
          expect(subject).to be_truthy
        end
      end

      context 'when some but not all corresponding rated disabilities are not service-connected' do
        let(:form_json_filename) { 'only_526_two_rated_disabilities.json' }

        it 'returns false' do
          expect(subject).to be_falsey
        end
      end

      context 'when some disabilities do not have a ratedDisabilityId yet' do
        let(:form_json_filename) { 'only_526_mixed_action_disabilities.json' }

        it 'returns false' do
          expect(subject).to be_falsey
        end
      end
    end
  end

  describe '#cfi_checkbox_was_selected?' do
    subject { form_526_submission.cfi_checkbox_was_selected? }

    let!(:in_progress_form) { create(:in_progress_526_form, user_uuid: user.uuid) }
    let(:form_526_submission) do
      Form526Submission.create(
        user_uuid: user.uuid,
        user_account: user.user_account,
        saved_claim_id: saved_claim.id,
        auth_headers_json: auth_headers.to_json,
        form_json: File.read('spec/support/disability_compensation_form/submissions/only_526_tinnitus.json')
      )
    end

    context 'when associated with a default InProgressForm' do
      it 'returns false' do
        expect(subject).to be_falsey
      end
    end

    context 'when associated with a InProgressForm that went through CFI being selected' do
      let(:params) do
        { form_data: { 'view:claim_type' => { 'view:claiming_increase' => true } } }
      end

      it 'returns true' do
        ClaimFastTracking::MaxCfiMetrics.log_form_update(in_progress_form, params)
        in_progress_form.update!(params)
        expect(subject).to be_truthy
      end
    end
  end

  describe '#eligible_for_ep_merge?' do
    subject { Form526Submission.create(form_json: File.read(path)).eligible_for_ep_merge? }

    before { Flipper.disable(:disability_526_ep_merge_multi_contention) }

    context 'when there are multiple contentions' do
      let(:path) { 'spec/support/disability_compensation_form/submissions/only_526_mixed_action_disabilities.json' }

      context 'when multi-contention claims are not eligible' do
        it { is_expected.to be_falsey }
      end

      context 'when multi-contention claims are eligible' do
        before { Flipper.enable(:disability_526_ep_merge_multi_contention) }

        it { is_expected.to be_truthy }
      end
    end

    context 'when there is a single new contention' do
      let(:path) { 'spec/support/disability_compensation_form/submissions/only_526_new_disability.json' }

      context 'when new claims are eligible' do
        before { Flipper.enable(:disability_526_ep_merge_new_claims) }
        after { Flipper.disable(:disability_526_ep_merge_new_claims) }

        it { is_expected.to be_truthy }
      end

      context 'when new claims are not eligible' do
        before { Flipper.disable(:disability_526_ep_merge_new_claims) }
        after { Flipper.enable(:disability_526_ep_merge_new_claims) }

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#remediated?' do
    context 'when there are no form526_submission_remediations' do
      it 'returns false' do
        expect(subject).not_to be_remediated
      end
    end

    context 'when there are form526_submission_remediations' do
      let(:remediation) do
        FactoryBot.create(:form526_submission_remediation, form526_submission: subject)
      end

      it 'returns true if the most recent remediation was successful' do
        remediation.update(success: true)
        expect(subject).to be_remediated
      end

      it 'returns false if the most recent remediation was not successful' do
        remediation.update(success: false)
        expect(subject).not_to be_remediated
      end
    end
  end

  describe '#duplicate?' do
    context 'when there are no form526_submission_remediations' do
      it 'returns false' do
        expect(subject).not_to be_duplicate
      end
    end

    context 'when there are form526_submission_remediations' do
      let(:remediation) do
        FactoryBot.create(:form526_submission_remediation, form526_submission: subject)
      end

      it 'returns true if the most recent remediation ignored_as_duplicate value is true' do
        remediation.update(ignored_as_duplicate: true)
        expect(subject).to be_duplicate
      end

      it 'returns false if the most recent remediation ignored_as_duplicate value is false' do
        remediation.update(ignored_as_duplicate: false)
        expect(subject).not_to be_duplicate
      end
    end
  end

  describe '#success_type?' do
    let(:remediation) do
      FactoryBot.create(:form526_submission_remediation, form526_submission: subject)
    end

    context 'when submitted_claim_id is present and backup_submitted_claim_status is nil' do
      subject { create(:form526_submission, :with_submitted_claim_id) }

      it 'returns true' do
        expect(subject).to be_success_type
      end
    end

    context 'when backup_submitted_claim_id is present and backup_submitted_claim_status is accepted' do
      subject { create(:form526_submission, :backup_path, :backup_accepted) }

      it 'returns true' do
        expect(subject).to be_success_type
      end
    end

    context 'when the most recent remediation is successful' do
      it 'returns true' do
        remediation.update(success: true)
        expect(subject).to be_success_type
      end
    end

    context 'when none of the success conditions are met' do
      it 'returns false' do
        remediation.update(success: false)
        expect(subject).not_to be_success_type
      end
    end
  end

  describe '#in_process?' do
    context 'when submitted_claim_id and backup_submitted_claim_status are both nil' do
      context 'and the record was created within the last 3 days' do
        it 'returns true' do
          expect(subject).to be_in_process
        end
      end

      context 'and the record was created more than 3 weeks ago' do
        subject { create(:form526_submission, :created_more_than_3_weeks_ago) }

        it 'returns false' do
          expect(subject).not_to be_in_process
        end
      end
    end

    context 'when submitted_claim_id is not nil' do
      subject { create(:form526_submission, :with_submitted_claim_id) }

      it 'returns false' do
        expect(subject).not_to be_in_process
      end
    end

    context 'when backup_submitted_claim_status is not nil' do
      subject { create(:form526_submission, :backup_path, :backup_accepted) }

      it 'returns false' do
        expect(subject).not_to be_in_process
      end
    end
  end

  describe '#failure_type?' do
    context 'when the submission is a success type' do
      subject { create(:form526_submission, :with_submitted_claim_id) }

      it 'returns true' do
        expect(subject).not_to be_failure_type
      end
    end

    context 'when the submission is in process' do
      it 'returns false' do
        expect(subject).not_to be_failure_type
      end
    end

    context 'when the submission is neither a success type nor in process' do
      subject { create(:form526_submission, :created_more_than_3_weeks_ago) }

      it 'returns true' do
        expect(subject).to be_failure_type
      end
    end
  end
end
