# frozen_string_literal: true

require 'rails_helper'

describe Workflow::File do
  let(:defined_flow) { Class.new(Workflow::File) }
  let(:shrine_attacher) do
    attacher = Shrine::Attacher.new(InternalAttachment.new({}), :file)
    attacher.assign(File.open(Rails.root.join('README.md')))
    attacher
  end

  context '#initialize' do
    context 'with a Shrine::Attacher as the first argument' do
      it 'sets internal metadata' do
        instance = defined_flow.new(shrine_attacher, a: :b)
        vars = instance.instance_variable_get(:@internal_options)
        expect(vars[:attacher_class]).to eq('Shrine::Attacher')
        expect(vars[:file]).to be_a(String)
      end
    end

    it 'raises an exception first arg is not an attacher' do
      expect do
        defined_flow.new(Object.new, a: :b)
      end.to raise_exception(Exception, /Shrine/)
    end
  end
end
