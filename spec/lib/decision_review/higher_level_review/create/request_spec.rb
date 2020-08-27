# frozen_string_literal: true

require 'rails_helper'

describe DecisionReview::HigherLevelReview::Create::Request do
  let(:ssn_with_mockdata) { '212222112' }
  let(:user) { build(:user, :loa3, ssn: ssn_with_mockdata) }

  let(:data) { Struct.new(:headers, :body).new headers, body }

  let(:headers) do
    {
      'X-VA-SSN' => user.ssn,
      'X-VA-First-Name' => user.first_name,
      'X-VA-Middle-Initial' => user.middle_name.presence&.first,
      'X-VA-Last-Name' => user.last_name,
      'X-VA-Birth-Date' => user.birth_date
    }
  end

  let(:body) { get_fixture 'decision_review/valid_200996.json' }

  describe '#initialize' do # initialize can throw exception
    it 'creates a request object' do
      expect { described_class.new(data) }.not_to raise DecisionReview::RequestSchemaError
    end
  end
end
