# frozen_string_literal: true

require 'rails_helper'
require 'mvi/messages/message_builder'

describe MVI::Messages::MessageBuilder do
  let(:dummy_class) { Class.new { extend MVI::Messages::MessageBuilder } }

  describe '#build_idm' do
    let(:el) { dummy_class.build_idm('PRPA_IN201305UV02') }
    it 'has mvi attributes' do
      expect(el.attributes).to eq(
        'xmlns:idm' => 'http://vaww.oed.oit.va.gov',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema‐instance',
        'xsi:schemaLocation' => 'urn:hl7‐org:v3 ../../schema/HL7V3/NE2008/multicacheschemas/PRPA_IN201305UV02.xsd',
        'xmlns' => 'urn:hl7‐org:v3',
        'ITSVersion' => 'XML_1.0'
      )
    end
  end

  describe '#add_header' do
    let(:message) { dummy_class.add_header(dummy_class.element('foo'), 'PRPA_IN201305UV02') }

    it 'has a 200VGOV extension with a uuid' do
      allow(SecureRandom).to receive(:uuid).and_return('9cb52fb1-583c-448d-92d4-61abe0136465')
      expect(message.locate('id').first.attributes).to eq(
        root: '1.2.840.114350.1.13.0.1.7.1.1',
        extension: '200VGOV-9cb52fb1-583c-448d-92d4-61abe0136465'
      )
    end

    it 'has a creation time node' do
      time = Time.now.utc
      allow(Time).to receive(:now).and_return(time)
      expect(message.locate('creationTime').first.attributes).to eq(value: time.strftime('%Y%m%d%H%M%S'))
    end

    it 'has a version code node' do
      expect(message.locate('versionCode').first.attributes).to eq(code: '3.0')
    end

    it 'has an interaction id node' do
      expect(message.locate('interactionId').first.attributes).to eq(
        root: '2.16.840.1.113883.1.6', extension: 'PRPA_IN201305UV02'
      )
    end

    describe 'processing code node' do
      context 'in non-production environments' do
        it 'has a processing code node of T' do
          with_settings(Settings.mvi, processing_code: 'T') do
            expect(message.locate('processingCode').first.attributes).to eq(code: 'T')
          end
        end
      end
      context 'in production environments' do
        it 'has a processing code node of P' do
          with_settings(Settings.mvi, processing_code: 'P') do
            expect(message.locate('processingCode').first.attributes).to eq(code: 'P')
          end
        end
      end
    end

    it 'has a processing mode code node' do
      expect(message.locate('processingModeCode').first.attributes).to eq(code: 'T')
    end

    it 'has a accept ack code node' do
      expect(message.locate('acceptAckCode').first.attributes).to eq(code: 'AL')
    end

    it 'has a receiver node' do
      expect(message.locate('receiver').first.attributes).to eq(typeCode: 'RCV')
      expect(message.locate('receiver/device').first.attributes).to eq(classCode: 'DEV', determinerCode: 'INSTANCE')
      expect(message.locate('receiver/device/id').first.attributes).to eq(
        root: '1.2.840.114350.1.13.999.234', extension: '200M'
      )
    end

    it 'has a sender node' do
      expect(message.locate('sender').first.attributes).to eq(typeCode: 'SND')
      expect(message.locate('sender/device').first.attributes).to eq(classCode: 'DEV', determinerCode: 'INSTANCE')
      expect(message.locate('sender/device/id').first.attributes).to eq(
        root: '2.16.840.1.113883.4.349', extension: '200VGOV'
      )
    end
  end

  describe '#element' do
    it 'creates a node with a value' do
      el = dummy_class.element('foo')
      expect(el.value).to eq('foo')
    end

    it 'creates a node with text' do
      el = dummy_class.element('foo', text!: 'bar')
      expect(el.text).to eq('bar')
    end

    it 'creates a node with attributes' do
      el = dummy_class.element('foo', first: 'John', last: 'Smith')
      expect(el.attributes).to eq(first: 'John', last: 'Smith')
    end

    it 'creates a node with attributes and text' do
      el = dummy_class.element('foo', text!: 'bar', first: 'John', last: 'Smith')
      expect(el.text).to eq('bar')
      expect(el.attributes).to eq(first: 'John', last: 'Smith')
    end
  end

  describe '#build_envelope_body' do
    context 'with a message' do
      let(:message) { dummy_class.element('foo', text!: 'bar', first: 'John', last: 'Smith') }
      let(:el) { dummy_class.build_envelope }
      it 'has soap attributes' do
        expect(el.attributes).to eq(
          'xmlns:soapenc' => 'http://schemas.xmlsoap.org/soap/encoding/',
          'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
          'xmlns:env' => 'http://schemas.xmlsoap.org/soap/envelope/',
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance'
        )
      end
    end
  end
end
