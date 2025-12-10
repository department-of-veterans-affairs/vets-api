# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Flipper::UI::ActionPatch do
  # Create a test class that includes the module
  let(:test_class) do
    Class.new do
      include Flipper::UI::ActionPatch

      # Mock the views_path method that would typically come from Flipper::UI::Action
      def views_path
        @views_path ||= Pathname.new(File.expand_path('../../fixtures/flipper_views', __dir__))
      end
    end
  end

  let(:instance) { test_class.new }
  let(:custom_views_dir) { Rails.root.join('lib', 'flipper', 'ui', 'views') }
  let(:default_views_dir) { instance.views_path }

  before do
    # Clean up any existing test directories
    FileUtils.rm_rf(custom_views_dir) if custom_views_dir.exist?
    FileUtils.rm_rf(default_views_dir) if default_views_dir.exist?
  end

  after do
    # Clean up test directories
    FileUtils.rm_rf(custom_views_dir) if custom_views_dir.exist?
    FileUtils.rm_rf(default_views_dir) if default_views_dir.exist?
  end

  describe '#view' do
    context 'when using default views' do
      before do
        FileUtils.mkdir_p(default_views_dir)
        File.write(
          default_views_dir.join('test_view.erb'),
          '<h1>Default View</h1><p><%= "Hello World" %></p>'
        )
      end

      it 'renders the default view when no custom views directory exists' do
        result = instance.view('test_view')
        expect(result).to include('Default View')
        expect(result).to include('Hello World')
      end

      it 'escapes HTML in the view by default' do
        File.write(
          default_views_dir.join('escape_test.erb'),
          '<%= "<script>alert(\'xss\')</script>" %>'
        )

        result = instance.view('escape_test')
        expect(result).to include('&lt;script&gt;')
        expect(result).not_to include('<script>')
      end
    end

    context 'when using custom views' do
      before do
        FileUtils.mkdir_p(custom_views_dir)
        FileUtils.mkdir_p(default_views_dir)

        File.write(
          custom_views_dir.join('custom_view.erb'),
          '<h1>Custom View</h1><p><%= "Custom Content" %></p>'
        )

        File.write(
          default_views_dir.join('custom_view.erb'),
          '<h1>Default View</h1><p><%= "Default Content" %></p>'
        )
      end

      it 'renders the custom view when it exists' do
        result = instance.view('custom_view')
        expect(result).to include('Custom View')
        expect(result).to include('Custom Content')
        expect(result).not_to include('Default View')
      end
    end

    context 'when custom view does not exist but default does' do
      before do
        FileUtils.mkdir_p(custom_views_dir)
        FileUtils.mkdir_p(default_views_dir)

        File.write(
          default_views_dir.join('fallback_view.erb'),
          '<h1>Fallback to Default</h1>'
        )
      end

      it 'falls back to the default view' do
        result = instance.view('fallback_view')
        expect(result).to include('Fallback to Default')
      end
    end

    context 'when neither custom nor default view exists' do
      it 'raises an error with descriptive message' do
        expect { instance.view('nonexistent_view') }.to raise_error(
          RuntimeError,
          /Template does not exist:.*nonexistent_view\.erb/
        )
      end
    end

    context 'when custom_views_path is nil' do
      before do
        FileUtils.mkdir_p(default_views_dir)
        File.write(
          default_views_dir.join('nil_custom_path.erb'),
          '<h1>Default Only</h1>'
        )

        allow(instance).to receive(:custom_views_path).and_return(nil)
      end

      it 'uses the default view' do
        result = instance.view('nil_custom_path')
        expect(result).to include('Default Only')
      end
    end

    context 'with complex ERB templates' do
      before do
        FileUtils.mkdir_p(default_views_dir)
      end

      it 'handles ERB conditionals' do
        File.write(
          default_views_dir.join('conditional.erb'),
          '<% if true %><p>Visible</p><% else %><p>Hidden</p><% end %>'
        )

        result = instance.view('conditional')
        expect(result).to include('Visible')
        expect(result).not_to include('Hidden')
      end

      it 'handles ERB loops' do
        File.write(
          default_views_dir.join('loop.erb'),
          '<% [1, 2, 3].each do |n| %><p>Item <%= n %></p><% end %>'
        )

        result = instance.view('loop')
        expect(result).to include('Item 1')
        expect(result).to include('Item 2')
        expect(result).to include('Item 3')
      end

      it 'has access to instance variables' do
        instance.instance_variable_set(:@title, 'Test Title')

        File.write(
          default_views_dir.join('instance_var.erb'),
          '<h1><%= @title %></h1>'
        )

        result = instance.view('instance_var')
        expect(result).to include('Test Title')
      end
    end

    context 'with special characters in template' do
      before do
        FileUtils.mkdir_p(default_views_dir)
      end

      it 'properly escapes ampersands' do
        File.write(
          default_views_dir.join('ampersand.erb'),
          '<%= "Beans & Rice" %>'
        )

        result = instance.view('ampersand')
        expect(result).to include('Beans &amp; Rice')
      end

      it 'properly escapes quotes' do
        File.write(
          default_views_dir.join('quotes.erb'),
          '<%= "Say \\"Hello\\"" %>'
        )

        result = instance.view('quotes')
        expect(result).to include('&quot;')
      end

      it 'properly escapes less-than and greater-than signs' do
        File.write(
          default_views_dir.join('brackets.erb'),
          '<%= "1 < 2 > 0" %>'
        )

        result = instance.view('brackets')
        expect(result).to include('1 &lt; 2 &gt; 0')
      end
    end
  end

  describe '#custom_views_path' do
    it 'returns the correct path to custom views directory' do
      expected_path = Rails.root.join('lib', 'flipper', 'ui', 'views')
      expect(instance.custom_views_path).to eq(expected_path)
    end

    it 'returns a Pathname object' do
      expect(instance.custom_views_path).to be_a(Pathname)
    end
  end

  describe 'view resolution priority' do
    before do
      FileUtils.mkdir_p(custom_views_dir)
      FileUtils.mkdir_p(default_views_dir)
    end

    it 'prioritizes custom views over default views' do
      File.write(custom_views_dir.join('priority.erb'), 'CUSTOM')
      File.write(default_views_dir.join('priority.erb'), 'DEFAULT')

      result = instance.view('priority')
      expect(result).to eq('CUSTOM')
    end

    it 'uses default view when custom directory exists but view does not' do
      # Create custom directory but not the specific view
      File.write(custom_views_dir.join('other.erb'), 'OTHER')
      File.write(default_views_dir.join('specific.erb'), 'DEFAULT')

      result = instance.view('specific')
      expect(result).to eq('DEFAULT')
    end
  end

  describe 'error handling' do
    it 'raises error with full path when template is missing' do
      expect { instance.view('missing') }.to raise_error do |error|
        expect(error.message).to include('Template does not exist:')
        expect(error.message).to include('missing.erb')
      end
    end

    it 'raises error for invalid ERB syntax' do
      FileUtils.mkdir_p(default_views_dir)
      File.write(default_views_dir.join('invalid.erb'), '<% if true %>')

      expect { instance.view('invalid') }.to raise_error(SyntaxError)
    end
  end

  describe 'integration scenarios' do
    before do
      FileUtils.mkdir_p(custom_views_dir)
      FileUtils.mkdir_p(default_views_dir)
    end

    it 'works with multiple view calls' do
      File.write(default_views_dir.join('view1.erb'), 'View 1')
      File.write(default_views_dir.join('view2.erb'), 'View 2')

      result1 = instance.view('view1')
      result2 = instance.view('view2')

      expect(result1).to eq('View 1')
      expect(result2).to eq('View 2')
    end

    it 'maintains state between view calls' do
      instance.instance_variable_set(:@counter, 0)

      File.write(
        default_views_dir.join('stateful.erb'),
        '<% @counter += 1 %><%= @counter %>'
      )

      result1 = instance.view('stateful')
      result2 = instance.view('stateful')

      expect(result1).to eq('1')
      expect(result2).to eq('2')
    end
  end
end
