# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::LoadData do
  let(:source) { :bdn_feed }
  let(:locator) { 'test' }
  let(:bdn_clone) { create(:vye_bdn_clone_base) }
  let(:records) do
    {
      profile: {
        ssn: '123456789',
        file_number: ''
      },
      info: {
        file_number: '',
        dob: '19800101',
        mr_status: 'E',
        rem_ent: '3600000',
        cert_issue_date: '19860328',
        del_date: '19960205',
        date_last_certified: '19860328',
        stub_nm: 'JAPPLES',
        rpo_code: '316',
        fac_code: '11907111',
        payment_amt: '0011550',
        indicator: 'A'
      },
      address: {
        veteran_name: 'JOHN APPLESEED',
        address1: '1 Mockingbird Ln',
        address2: 'APT 1',
        address3: 'Houston TX',
        address4: '',
        address5: '',
        zip_code: '77401',
        origin: 'backend'
      },
      awards: [
        {
          award_begin_date: '00000000',
          award_end_date: '19860328',
          training_time: '1',
          payment_date: '19860328',
          monthly_rate: 35.0,
          begin_rsn: '',
          end_rsn: '66',
          type_training: '',
          number_hours: '00',
          type_hours: '',
          cur_award_ind: 'C'
        }
      ]
    }
  end

  describe '::new' do
    it 'can be instantiated' do
      r = described_class.new(source:, locator:, bdn_clone:, records:)

      expect(r).to be_a described_class
      expect(r.valid?).to be(true)
    end

    it 'reports the exception if source is invalid' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)
      expect(StatsD).to receive(:increment).with('vye.load_data.failure.no_source')
      expect(Sentry).to receive(:capture_exception).with(an_instance_of(ArgumentError))

      r = described_class.new(source: :something_else, locator:, bdn_clone:, records:)

      expect(r.valid?).to be(false)
    end

    it 'reports the exception if locator is blank' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)
      expect(StatsD).to receive(:increment).with('vye.load_data.failure.bdn_feed')
      expect(Sentry).to receive(:capture_exception).with(an_instance_of(ArgumentError))

      r = described_class.new(source:, locator: nil, bdn_clone:, records:)

      expect(r.valid?).to be(false)
    end

    it 'reports the exception if bdn_clone is blank' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)
      expect(StatsD).to receive(:increment).with('vye.load_data.failure.bdn_feed')
      expect(Sentry).to receive(:capture_exception).with(an_instance_of(ArgumentError))

      r = described_class.new(source:, locator:, bdn_clone: nil, records:)

      expect(r.valid?).to be(false)
    end

    it 'reports the exception if profile attributes hash is incorrect' do
      expect(Rails.logger).to receive(:error).with(/Loading data failed:/)
      expect(StatsD).to receive(:increment).with('vye.load_data.failure.bdn_feed')
      expect(Sentry).to receive(:capture_exception).with(an_instance_of(NoMatchingPatternKeyError))

      r = described_class.new(source:, locator:, bdn_clone:, records: records.merge(profile: { invalid: 'data' }))

      expect(r.valid?).to be(false)
    end
  end

  describe '#load_profile' do
    let(:described_instance) { described_class.allocate }
    let(:user_profile) { instance_double(Vye::UserProfile) }

    before do
      allow(described_instance).to receive(:load_info)
      allow(described_instance).to receive(:load_address)
      allow(described_instance).to receive(:load_awards)

      allow(Vye::UserProfile).to receive(:produce).and_return(user_profile)
    end

    context 'when UserProfile gets loaded unchanged' do
      before do
        allow(user_profile).to receive_messages(
          new_record?: false,
          changed?: false
        )
      end

      it "doesn't report an exception" do
        described_instance.send(:initialize, source:, locator:, bdn_clone:, records:)

        expect(described_instance.valid?).to be(true)
      end
    end

    context 'when UserProfile gets loaded from BDN feed as a new record' do
      before do
        allow(user_profile).to receive(:new_record?).and_return(true)
      end

      it "doesn't report an exception" do
        expect(StatsD).to receive(:increment).with('vye.load_data.user_profile.created')
        expect(user_profile).to receive(:save!).and_return(true)

        described_instance.send(:initialize, source:, locator:, bdn_clone:, records:)

        expect(described_instance.valid?).to be(true)
      end
    end

    context 'when UserProfile gets loaded from BDN feed with changed' do
      before do
        allow(user_profile).to(
          receive_messages(
            new_record?: false,
            changed?: true,
            id: 1,
            changed_attributes: {
              'ssn_digest' => 'old_ssn_digest',
              'file_number' => 'old_file_number'
            }
          )
        )
      end

      it "doesn't report an exception" do
        expect(StatsD).to receive(:increment).with('vye.load_data.user_profile.updated')
        expect(user_profile).to receive(:save!).and_return(true)

        described_instance.send(:initialize, source:, locator:, bdn_clone:, records:)

        expect(described_instance.valid?).to be(true)
      end
    end

    # context 'when UserProfile gets loaded from TIMS feed as a new record' do
    # end

    # context 'when UserProfile gets loaded from TIMS feed with changed' do
    # end
  end
end
