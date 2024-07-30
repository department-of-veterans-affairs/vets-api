# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReview::DeleteSavedClaimRecordsJob, type: :job do
  subject { described_class }

  let(:delete_date_1) { DateTime.new(2024, 1, 1) }
  let(:delete_date_2) { DateTime.new(2024, 1, 2) }
  let(:delete_date_3) { DateTime.new(2024, 1, 3) }
  let(:delete_date_4) { DateTime.new(2024, 1, 4) }
  let(:delete_date_5) { DateTime.new(2024, 1, 5) }

  describe 'perform' do
    context 'when feature flag is enabled' do
      before do
        Flipper.enable :decision_review_delete_saved_claims_job_enabled
      end

      context 'when SavedClaim records have a delete_date set' do
        let(:guid_1) { SecureRandom.uuid }
        let(:guid_2) { SecureRandom.uuid }
        let(:guid_3) { SecureRandom.uuid }
        let(:guid_4) { SecureRandom.uuid }

        before do
          ::SavedClaim::SupplementalClaim.create(guid: guid_1, form: '{}', delete_date: delete_date_1)
          ::SavedClaim::NoticeOfDisagreement.create(guid: guid_2, form: '{}', delete_date: delete_date_2)
          ::SavedClaim::HigherLevelReview.create(guid: guid_3, form: '{}', delete_date: delete_date_3)
          ::SavedClaim::HigherLevelReview.create(guid: guid_4, form: '{}', delete_date: delete_date_4)
        end

        it 'deletes only the records with a past or current delete_time' do
          Timecop.freeze(delete_date_2) do
            subject.new.perform

            expect(::SavedClaim.pluck(:guid)).to contain_exactly(guid_3, guid_4)
          end
        end
      end

      context 'when SavedClaim records do not have a delete_date set' do
        let(:guid_1) { SecureRandom.uuid }
        let(:guid_2) { SecureRandom.uuid }
        let(:guid_3) { SecureRandom.uuid }

        before do
          ::SavedClaim::SupplementalClaim.create(guid: guid_1, form: '{}')
          ::SavedClaim::NoticeOfDisagreement.create(guid: guid_2, form: '{}')
          ::SavedClaim::HigherLevelReview.create(guid: guid_3, form: '{}')
        end

        it 'does not delete the records' do
          Timecop.freeze(delete_date_4) do
            subject.new.perform

            expect(::SavedClaim.pluck(:guid)).to contain_exactly(guid_1, guid_2, guid_3)
          end
        end
      end
    end

    context 'when feature flag is disabled' do
      let(:guid_1) { SecureRandom.uuid }
      let(:guid_2) { SecureRandom.uuid }

      before do
        Flipper.disable :decision_review_delete_saved_claims_job_enabled

        ::SavedClaim::SupplementalClaim.create(guid: guid_1, form: '{}', delete_date: delete_date_1)
        ::SavedClaim::NoticeOfDisagreement.create(guid: guid_2, form: '{}')
      end

      it 'does not delete any records even if delete_date is in the past' do
        Timecop.freeze(delete_date_4) do
          subject.new.perform

          expect(::SavedClaim.pluck(:guid)).to contain_exactly(guid_1, guid_2)
        end
      end
    end
  end
end
