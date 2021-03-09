# frozen_string_literal: true

require 'rails_helper'
require 'vetext/response_error'

describe VEText::ResponseError do

  describe '#initialize' do
    let(:body) do
      {
          error: 'Invalid Application SID',
          id: '123',
          idType: 'appSid',
          success: false
      }
    end

    it 'initializes the error successfully with the provided data' do
      subject = described_class.new(body)
      expect(subject).not_to be_nil
      expect(subject.instance_variable_get(:@id)).to be(body[:id])
      expect(subject.instance_variable_get(:@id_type)).to be(body[:idType])
    end
  end
end
