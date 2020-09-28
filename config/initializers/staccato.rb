# frozen_string_literal: true

def Staccato.ga_collection_uri(*_args)
  URI("#{Settings.google_analytics.url}/collect")
end
