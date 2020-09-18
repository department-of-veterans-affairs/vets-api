# frozen_string_literal: true

require 'rails_helper'

describe Caseflow::Middleware::Errors do
  it 'handles errors' do
    env = OpenStruct.new('success?' => false, status: 'status', body: {})
    expect do
      described_class.new.on_complete(env)
    end.to change { env[:body]['source'] }.from(nil).to('Appeals Caseflow')
  end
end
