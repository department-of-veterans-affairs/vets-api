# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { FactoryBot.build(:va10203) }
  let(:user) { create(:evss_user) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10203')

  describe '#in_progress_form_id' do
    it 'returns 22-10203' do
      expect(instance.in_progress_form_id).to eq('22-10203')
    end
  end

  describe '#after_submit' do
    context 'authorized' do
      before do
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(true)
      end

      context 'sco email sent is false' do
        let(:gi_bill_status) { build(:gi_bill_status_response) }

        context '' do
          before do
            bad_gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: {})
            allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
              .and_return(bad_gi_bill_status)
          end

          it 'when no remaining entitlement is present' do
            instance.after_submit(user)
            expect(instance.parsed_form['scoEmailSent']).to eq(false)
          end
        end

        # it 'when no facility code is present' do
        #   bad_gi_bill_status = {
        #     remaining_entitlement: { months: 0, days: 12 },
        #     enrollments: []
        #   }
        #   allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
        #     .and_return(bad_gi_bill_status)
        #
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end

        # it 'when FeatureFlipper.send_email? is false' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when more than six months of entitlement remaining' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when institution is blank' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when school has changed' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
        #
        # it 'when neither a primary or secondary sco with an email address is found' do
        #   instance.after_submit(user)
        #   expect(instance.parsed_form['scoEmailSent']).to eq(false)
        # end
      end
    end

    context 'unauthorized' do
      it 'sco email sent is false' do
        unauthorized_evss_user = build(:unauthorized_evss_user, :loa3)

        instance.after_submit(unauthorized_evss_user)
        expect(instance.parsed_form['scoEmailSent']).to eq(false)
      end
    end
  end
end
