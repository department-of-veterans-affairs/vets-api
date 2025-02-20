# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'

describe ClaimsApi::Logger do
  let(:icn) { '1012667169V030190' }
  let(:cid) { '8675309' }
  let(:current_user) { '1012667169V030190' }
  let(:api_version) { 'V1' }

  describe 'When it recieves a message object' do
    let(:expected_msg) do
      'ClaimsApi :: validate_identifiers :: {:icn=>"1012667169V030190", :cid=>"8675309", ' \
        ':current_user=>"1012667169V030190", :message=>"multiple_ids: 2, header_request: true, ' \
        'require_birls: true, birls_id: true, rid: 8675309, ptcpnt_id: true", :api_version=>"V1"} :: '
    end

    let(:v1_application_controller_message_content) do
      'multiple_ids: 2, header_request: true, require_birls: true, ' \
        'birls_id: true, rid: 8675309, ptcpnt_id: true'
    end

    it 'logs the message as expected' do
      res = described_class.format_msg('validate_identifiers', icn:, cid:, current_user:,
                                                               message: v1_application_controller_message_content,
                                                               api_version:)

      # Leaving off the Location value, or source, from the message check since that is coming
      # from RSpec and would change with a version change, which would breaking this test
      expect(res).to include(expected_msg.to_s)
    end
  end
end
