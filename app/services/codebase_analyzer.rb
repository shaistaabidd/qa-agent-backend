# v1 heuristic scope-feature extractor: parses config/routes.rb for a Rails
# target app, falling back to one feature per controller file if no routes
# file is found. This is a placeholder for the LLM-based codebase
# understanding the spec ultimately calls for — swapping in a real analyzer
# later only means replacing this class; ScanCodebase doesn't need to change.
class CodebaseAnalyzer
  ROUTE_LINE = /^\s*(get|post|patch|put|delete)\s+["']([^"']+)["']/

  def initialize(github_service, repo_full_name)
    @github_service = github_service
    @repo_full_name = repo_full_name
  end

  def extract_features
    rails_routes_features || controller_file_features
  end

  private

  attr_reader :github_service, :repo_full_name

  def rails_routes_features
    content = github_service.file_content(repo_full_name, 'config/routes.rb')
    return nil if content.blank?

    content.scan(ROUTE_LINE).map do |verb, route|
      { name: "#{verb.upcase} #{route}", route: route, source: 'config/routes.rb' }
    end.uniq
  end

  def controller_file_features
    entries = github_service.directory_entries(repo_full_name, path: 'app/controllers')
    entries.select { |entry| entry.type == 'file' }.map do |entry|
      {
        name: entry.name.sub(/_controller\.rb\z/, '').tr('_', ' ').capitalize,
        route: nil,
        source: entry.path
      }
    end
  end
end
