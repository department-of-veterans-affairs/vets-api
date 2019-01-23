# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::Scaffold do
  let(:http_ok) { 200 }

  subject { Users::Scaffold.new([], http_ok) }

  context 'an instance of Scaffold' do
    it 'has #errors as the first parameter' do
      expect(subject.errors).to eq []
    end

    it 'has #status as the second parameter' do
      expect(subject.status).to eq http_ok
    end
  end
end
