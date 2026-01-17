# frozen_string_literal: true

begin
  require "mcp"
rescue LoadError
  raise LoadError, <<~MSG
    The 'mcp' gem is required for MCP server support.
    Add `gem 'mcp'` to your Gemfile and run `bundle install`.
  MSG
end

require "coverband"
require "coverband/utils/html_formatter"
require "coverband/utils/result"
require "coverband/utils/file_list"
require "coverband/utils/source_file"
require "coverband/utils/lines_classifier"
require "coverband/utils/results"
require "coverband/reporters/json_report"

# Load dead methods support if available
if defined?(RubyVM::AbstractSyntaxTree)
  require "coverband/utils/dead_methods"
end

require_relative "mcp/server"
require_relative "mcp/http_handler"
