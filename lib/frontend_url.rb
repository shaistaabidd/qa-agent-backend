# Links in emails, and redirects back to the app, point at the frontend, never at this API.
module FrontendUrl
  module_function

  def build(path, fragment: nil, **query)
    uri = URI.join(Rails.configuration.x.frontend_url, path)
    uri.query = query.to_query if query.any?
    uri.fragment = fragment.to_query if fragment
    uri.to_s
  end
end
