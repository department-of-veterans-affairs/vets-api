# frozen_string_literal: true

ActionController::Renderers.add :geojson do |object, _options|
  self.content_type ||= 'application/vnd.geo+json'
  object.respond_to?(:to_json) ? object.to_json : object
end

ActionController::Renderers.add :csv do |obj, options|
  filename = options[:filename] || 'data'
  str = obj.respond_to?(:to_csv) ? obj.to_csv : obj.to_s
  send_data str, type: Mime[:csv],
                 disposition: "attachment; filename=#{filename}.csv"
end
