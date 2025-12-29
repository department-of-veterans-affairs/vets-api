# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_inspector/app'

RSpec.describe VcrInspector::App do
  subject(:app) { described_class.new }

  describe 'initialization' do
    it 'sets cassette_root' do
      expect(app.cassette_root).to end_with('spec/support/vcr_cassettes')
    end

    it 'sets spec_root' do
      expect(app.spec_root).to end_with('spec')
    end

    it 'sets modules_root' do
      expect(app.modules_root).to end_with('modules')
    end

    it 'sets views_dir' do
      expect(app.views_dir).to end_with('script/vcr_inspector/views')
    end

    it 'sets public_dir' do
      expect(app.public_dir).to end_with('script/vcr_inspector/public')
    end

    it 'has nil request initially' do
      expect(app.request).to be_nil
    end
  end

  describe '#format_json' do
    it 'formats valid JSON with pretty printing' do
      result = app.send(:format_json, '{"key":"value"}')
      expect(result).to include('"key"')
      expect(result).to include('"value"')
      expect(result).to include("\n")
    end

    it 'returns invalid JSON as-is' do
      result = app.send(:format_json, 'not json')
      expect(result).to eq('not json')
    end

    it 'returns nil for nil input' do
      result = app.send(:format_json, nil)
      expect(result).to be_nil
    end

    it 'returns empty string for empty input' do
      result = app.send(:format_json, '')
      expect(result).to eq('')
    end
  end

  describe '#format_date' do
    it 'formats valid date string' do
      result = app.send(:format_date, '2024-01-15T10:30:00Z')
      expect(result).to include('2024')
      expect(result).to include('January')
    end

    it 'returns Unknown for nil' do
      result = app.send(:format_date, nil)
      expect(result).to eq('Unknown')
    end

    it 'returns invalid date string as-is' do
      result = app.send(:format_date, 'not a date')
      expect(result).to eq('not a date')
    end
  end

  describe '#format_file_date' do
    it 'formats Time object' do
      time = Time.zone.local(2024, 6, 15)
      result = app.send(:format_file_date, time)
      expect(result).to include('June')
      expect(result).to include('2024')
    end

    it 'formats date string' do
      result = app.send(:format_file_date, '2024-03-20T10:00:00Z')
      expect(result).to include('March')
      expect(result).to include('2024')
    end
  end

  describe '#cassette_age_indicator' do
    it 'returns new indicator for recent cassettes' do
      recent = Time.zone.now - (10 * 86_400)
      result = app.send(:cassette_age_indicator, recent)
      expect(result).to eq('🆕')
    end

    it 'returns normal indicator for medium age cassettes' do
      medium = Time.zone.now - (100 * 86_400)
      result = app.send(:cassette_age_indicator, medium)
      expect(result).to eq('📼')
    end

    it 'returns warning indicator for old cassettes' do
      old = Time.zone.now - (300 * 86_400)
      result = app.send(:cassette_age_indicator, old)
      expect(result).to eq('⚠️')
    end

    it 'returns very old indicator for ancient cassettes' do
      very_old = Time.zone.now - (400 * 86_400)
      result = app.send(:cassette_age_indicator, very_old)
      expect(result).to eq('🕰️')
    end
  end

  describe '#http_method_emoji' do
    it 'returns green for GET' do
      expect(app.send(:http_method_emoji, 'GET')).to eq('🟢')
      expect(app.send(:http_method_emoji, 'get')).to eq('🟢')
    end

    it 'returns blue for POST' do
      expect(app.send(:http_method_emoji, 'POST')).to eq('🔵')
    end

    it 'returns yellow for PUT' do
      expect(app.send(:http_method_emoji, 'PUT')).to eq('🟡')
    end

    it 'returns orange for PATCH' do
      expect(app.send(:http_method_emoji, 'PATCH')).to eq('🟠')
    end

    it 'returns red for DELETE' do
      expect(app.send(:http_method_emoji, 'DELETE')).to eq('🔴')
    end

    it 'returns white for unknown methods' do
      expect(app.send(:http_method_emoji, 'OPTIONS')).to eq('⚪')
      expect(app.send(:http_method_emoji, 'HEAD')).to eq('⚪')
    end
  end

  describe '#status_class' do
    it 'returns success class for 2xx codes' do
      expect(app.send(:status_class, 200)).to eq('status-success')
      expect(app.send(:status_class, 201)).to eq('status-success')
      expect(app.send(:status_class, 204)).to eq('status-success')
    end

    it 'returns redirect class for 3xx codes' do
      expect(app.send(:status_class, 301)).to eq('status-redirect')
      expect(app.send(:status_class, 302)).to eq('status-redirect')
      expect(app.send(:status_class, 304)).to eq('status-redirect')
    end

    it 'returns client-error class for 4xx codes' do
      expect(app.send(:status_class, 400)).to eq('status-client-error')
      expect(app.send(:status_class, 401)).to eq('status-client-error')
      expect(app.send(:status_class, 404)).to eq('status-client-error')
    end

    it 'returns server-error class for 5xx codes' do
      expect(app.send(:status_class, 500)).to eq('status-server-error')
      expect(app.send(:status_class, 502)).to eq('status-server-error')
      expect(app.send(:status_class, 503)).to eq('status-server-error')
    end

    it 'returns unknown class for other codes' do
      expect(app.send(:status_class, 100)).to eq('status-unknown')
      expect(app.send(:status_class, 0)).to eq('status-unknown')
    end

    it 'handles string codes' do
      expect(app.send(:status_class, '200')).to eq('status-success')
      expect(app.send(:status_class, '404')).to eq('status-client-error')
    end
  end

  describe '#truncate' do
    it 'returns short text unchanged' do
      result = app.send(:truncate, 'short', 100)
      expect(result).to eq('short')
    end

    it 'returns exact length text unchanged' do
      text = 'a' * 100
      result = app.send(:truncate, text, 100)
      expect(result).to eq(text)
    end

    it 'truncates long text with ellipsis' do
      long_text = 'a' * 150
      result = app.send(:truncate, long_text, 100)
      expect(result.length).to eq(103)
      expect(result).to end_with('...')
    end
  end

  describe '#safe_encode' do
    it 'returns empty string for nil' do
      result = app.send(:safe_encode, nil)
      expect(result).to eq('')
    end

    it 'returns valid UTF-8 unchanged' do
      result = app.send(:safe_encode, 'hello')
      expect(result).to eq('hello')
    end

    it 'handles unicode characters' do
      result = app.send(:safe_encode, 'héllo wörld 🎉')
      expect(result).to include('héllo')
    end
  end

  describe '#highlight_json' do
    it 'escapes HTML characters' do
      result = app.send(:highlight_json, '<script>alert("xss")</script>')
      expect(result).to include('&lt;script&gt;')
      expect(result).not_to include('<script>')
    end

    it 'handles normal text' do
      result = app.send(:highlight_json, '{"key": "value"}')
      expect(result).to include('key')
      expect(result).to include('value')
    end
  end

  describe '#decode_base64_if_needed' do
    it 'returns nil for nil input' do
      result = app.send(:decode_base64_if_needed, nil)
      expect(result).to be_nil
    end

    it 'returns empty string for empty input' do
      result = app.send(:decode_base64_if_needed, '')
      expect(result).to eq('')
    end

    it 'returns short strings unchanged' do
      result = app.send(:decode_base64_if_needed, 'short')
      expect(result).to eq('short')
    end

    it 'returns non-base64 strings unchanged' do
      result = app.send(:decode_base64_if_needed, 'not-base64!')
      expect(result).to eq('not-base64!')
    end
  end

  describe '#extract_recorded_at' do
    it 'extracts max date from interactions' do
      cassette = {
        interactions: [
          { recorded_at: '2024-06-15T10:00:00Z' },
          { recorded_at: '2024-06-16T10:00:00Z' }
        ],
        raw: nil
      }
      file_info = instance_double(File::Stat, mtime: Time.zone.local(2020, 1, 1))

      result = app.send(:extract_recorded_at, cassette, file_info)
      expect(result.year).to eq(2024)
      expect(result.month).to eq(6)
      expect(result.day).to eq(16)
    end

    it 'falls back to raw yaml recorded_at' do
      cassette = {
        interactions: [],
        raw: { 'recorded_at' => '2023-05-10T15:00:00Z' }
      }
      file_info = instance_double(File::Stat, mtime: Time.zone.local(2020, 1, 1))

      result = app.send(:extract_recorded_at, cassette, file_info)
      expect(result.year).to eq(2023)
      expect(result.month).to eq(5)
    end

    it 'falls back to file mtime' do
      cassette = { interactions: [], raw: nil }
      file_mtime = Time.zone.local(2022, 3, 15)
      file_info = instance_double(File::Stat, mtime: file_mtime)

      result = app.send(:extract_recorded_at, cassette, file_info)
      expect(result).to eq(file_mtime)
    end

    it 'handles nil interactions' do
      cassette = { interactions: nil, raw: nil }
      file_mtime = Time.zone.local(2022, 3, 15)
      file_info = instance_double(File::Stat, mtime: file_mtime)

      result = app.send(:extract_recorded_at, cassette, file_info)
      expect(result).to eq(file_mtime)
    end
  end
end
