# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BGSDependents::Relationship do
  let(:event_date) { '2001/02/03' }
  let(:dependent) do
    {
      vnp_participant_id: '146189',
      participant_relationship_type_name: 'Spouse',
      family_relationship_type_name: 'Spouse',
      marriage_state: 'FL',
      marriage_city: 'Tampa',
      event_date:
    }
  end
  let(:params_response) do
    {
      vnp_proc_id: '1234',
      vnp_ptcpnt_id_a: '1234',
      vnp_ptcpnt_id_b: '146189',
      ptcpnt_rlnshp_type_nm: 'Spouse',
      family_rlnshp_type_nm: 'Spouse',
      event_dt: DateTime.parse("#{event_date} 12:00:00").to_time.iso8601
    }
  end

  describe 'params for 686c' do
    it 'formats relationship params for submission' do
      expect(
        described_class.new('1234')
          .params_for_686c('1234', dependent)
      ).to include(params_response)
    end
  end
end
