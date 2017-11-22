module NetHttpHeaderPatch
  refine Net::HTTPHeader do
    def capitalize(name) name end
  end
end
