# frozen_string_literal: true

require 'cgi'
require 'uri'

module CollieLsp
  # Helpers for converting LSP file URIs to local paths.
  module UriUtils
    module_function

    def path_from_uri(uri)
      parsed = URI.parse(uri)
      return CGI.unescape(uri.delete_prefix('file://')) unless parsed.scheme == 'file'

      path = CGI.unescape(parsed.path)
      return windows_path(path) if parsed.host.nil? || parsed.host.empty?

      "//#{parsed.host}#{path}"
    rescue URI::InvalidURIError
      CGI.unescape(uri.delete_prefix('file://'))
    end

    def windows_path(path)
      path.match?(%r{\A/[A-Za-z]:/}) ? path[1..] : path
    end
  end
end
