# frozen_string_literal: true

module FlipperExtensions
  module FeaturesMonkeyPatch
    def get
      @page_title = 'Features'
      @features = flipper.features.map do |feature|
        Flipper::UI::Decorators::Feature.new(feature)
      end.sort

      @show_blank_slate = @features.empty?

      breadcrumb 'Home', '/'
      breadcrumb 'Features'

      # Modified here to call out to our custom response renderer
      view_custom_response :features
    end

    # Modified to call our custom view rendering code
    def view_custom_response(view_name)
      header 'Content-Type', 'text/html'
      body = view_with_layout { custom_view view_name }
      halt [@code, @headers, [body]]
    end

    # Modified to return our custom template
    def custom_view(view_name)
      # Place your template in lib/flipper/features.erb
      # You can update this to wherever you want to place your modified views.
      path = Rails.root.join('lib', 'flipper', "#{view_name}.erb")

      raise "Template does not exist: #{path}" unless path.exist?

      contents = path.read
      compiled = Flipper::UI::Eruby.new(contents)
      compiled.result proc {}.binding
    end

    # This is where we store the feature descriptions.  You can choose to store this where it makes sense
    # for you.
    def yaml_features
      @yaml_features ||= FLIPPER_FEATURE_CONFIG['features']
    end
  end
end
