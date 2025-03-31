# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::Log, type: :model do
  subject { build(:audit_log) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:subject_user_identifier) }
    it { is_expected.to validate_presence_of(:acting_user_identifier) }
    it { is_expected.to validate_presence_of(:event_id) }
    it { is_expected.to validate_presence_of(:event_description) }
    it { is_expected.to validate_presence_of(:event_status) }
    it { is_expected.to validate_presence_of(:event_occurred_at) }
    it { is_expected.to validate_presence_of(:message) }
  end

  describe 'enums' do
    let(:expected_values) do
      {
        icn: 'icn',
        logingov_uuid: 'logingov_uuid',
        idme_uuid: 'idme_uuid',
        mhv_id: 'mhv_id',
        dslogon_id: 'dslogon_id',
        system_hostname: 'system_hostname'
      }
    end

    it {
      expect(subject).to define_enum_for(:subject_user_identifier_type).with_values(expected_values)
                                                                       .with_prefix(true)
                                                                       .backed_by_column_of_type(:enum)
    }

    it {
      expect(subject).to define_enum_for(:acting_user_identifier_type).with_values(expected_values)
                                                                      .with_prefix(true)
                                                                      .backed_by_column_of_type(:enum)
    }
  end
end
