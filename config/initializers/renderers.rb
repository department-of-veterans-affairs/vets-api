ActionController::Renderers.add :geojson do |object, options|
  self.content_type ||= "application/vnd.geo+json"
  object.respond_to?(:to_json) ? object.to_json : object
end
