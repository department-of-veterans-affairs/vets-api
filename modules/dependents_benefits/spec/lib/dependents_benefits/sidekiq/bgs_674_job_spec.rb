# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/sidekiq/bgs_674_job'
require 'bgsv2/form674'
require 'dependents_benefits/user_data'

RSpec.describe DependentsBenefits::Sidekiq::BGS674Job, type: :job do
  before do
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  let(:user) { create(:evss_user) }
  let(:parent_claim) { create(:dependents_claim) }
  let(:saved_claim) { create(:student_claim) }
  let(:user_data) { DependentsBenefits::UserData.new(user, saved_claim.parsed_form).get_user_json }
  let!(:parent_group) { create(:parent_claim_group, parent_claim:, user_data:) }
  let!(:current_group) { create(:saved_claim_group, saved_claim:, parent_claim:) }
  let(:job) { described_class.new }
  let(:bgs_service) { instance_double(BGSV2::Service) }
  let(:proc_id) { '123456' }

  describe '#perform' do
    before do
      allow(BGSV2::Service).to receive(:new).and_return(bgs_service)
      allow(bgs_service).to receive_messages(create_participant: {}, find_benefit_claim_type_increment: {},
                                             create_address: {}, get_regional_office_by_zip_code: {},
                                             find_regional_offices: {}, create_person: {}, create_phone: {},
                                             create_proc_form: {}, create_relationship: {},
                                             vnp_create_benefit_claim: {}, insert_benefit_claim: {},
                                             vnp_benefit_claim_update: {}, create_note: {}, update_proc: {},
                                             create_child_school: {}, create_child_student: {})
      allow_any_instance_of(BID::Awards::Service).to receive(:get_awards_pension).and_return(
        double('Response', body: { 'awards_pension' => { 'is_in_receipt_of_pension' => true } })
      )
    end

    context 'with valid claim' do
      it 'processes the claim successfully' do
        expect { job.perform(saved_claim.id, proc_id) }.not_to raise_error
      end

      it 'calls BGS service' do
        expect_any_instance_of(BGSV2::Form674).to receive(:submit).and_return({ status: 'success' })
        job.perform(saved_claim.id, proc_id)
      end
    end

    context 'with missing claim' do
      it 'raises error for non-existent claim' do
        expect { job.perform(999_999, proc_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with BGS service error' do
      it 'handles BGS errors gracefully' do
        allow_any_instance_of(BGSV2::Form674).to receive(:submit).and_raise(BGS::ShareError.new('failed', 500))
        expect { job.perform(saved_claim.id, proc_id) }.to raise_error(BGS::ShareError)
      end
    end
  end
end
