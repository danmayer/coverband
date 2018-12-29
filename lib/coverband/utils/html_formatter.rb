# frozen_string_literal: true

require 'erb'
require 'cgi'
require 'fileutils'
require 'digest/sha1'
require 'time'

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version pulled into Coverband from Simplecov 12/04/2018
####
module Coverband
  module Utils
    class HTMLFormatter
      attr_reader :notice, :base_path

      def initialize(report, options = {})
        @notice = options.fetch(:notice) { nil }
        @base_path = options.fetch(:base_path) { nil }
        @coverage_result = Coverband::Utils::Result.new(report)
      end

      def format!
        format(@coverage_result)
      end

      def format_html!
        format_html(@coverage_result)
      end

      private

      def format(result)
        Dir[File.join(File.dirname(__FILE__), '../../../public/*')].each do |path|
          FileUtils.cp_r(path, asset_output_path)
        end

        File.open(File.join(output_path, 'index.html'), 'wb') do |file|
          file.puts template('layout').result(binding)
        end
      end

      def format_html(result)
        template('layout').result(binding)
      end

      # Returns the an erb instance for the template of given name
      def template(name)
        ERB.new(File.read(File.join(File.dirname(__FILE__), '../../../views/', "#{name}.erb")))
      end

      def output_path
        "#{File.expand_path(Coverband.configuration.root)}/coverage"
      end

      def asset_output_path
        return @asset_output_path if defined?(@asset_output_path) && @asset_output_path
        @asset_output_path = File.join(output_path, 'assets', Coverband::VERSION)
        FileUtils.mkdir_p(@asset_output_path)
        @asset_output_path
      end

      def assets_path(name)
        if base_path
          File.join(base_path, name)
        else
          File.join(name)
        end
      end

      def button(url, title, opts = {})
        delete = opts.fetch(:delete) { false }
        button_css = delete ? 'coveraband-button del' : 'coveraband-button'
        button = "<form action='#{url}' class='coverband-admin-form' method='post'>"
        button += "<button class='#{button_css}' type='submit'>#{title}</button>"
        button + '</form>'
      end

      # Returns the html for the given source_file
      def formatted_source_file(source_file)
        template('source_file').result(binding)
      rescue Encoding::CompatibilityError => e
        puts "Encoding problems with file #{source_file.filename}. Coverband/ERB can't handle non ASCII characters in filenames. Error: #{e.message}."
      end

      # Returns a table containing the given source files
      def formatted_file_list(title, source_files)
        title_id = title.gsub(/^[^a-zA-Z]+/, '').gsub(/[^a-zA-Z0-9\-\_]/, '')
        # Silence a warning by using the following variable to assign to itself:
        # "warning: possibly useless use of a variable in void context"
        # The variable is used by ERB via binding.
        title_id = title_id
        template('file_list').result(binding)
      end

      def coverage_css_class(covered_percent)
        if covered_percent > 90
          'green'
        elsif covered_percent > 80
          'yellow'
        else
          'red'
        end
      end

      def strength_css_class(covered_strength)
        if covered_strength > 1
          'green'
        elsif covered_strength == 1
          'yellow'
        else
          'red'
        end
      end

      # Return a (kind of) unique id for the source file given. Uses SHA1 on path for the id
      def id(source_file)
        Digest::SHA1.hexdigest(source_file.filename)
      end

      def timeago(time)
        "<abbr class=\"timeago\" title=\"#{time.iso8601}\">#{time.iso8601}</abbr>"
      end

      def shortened_filename(source_file)
        source_file.filename.sub(Coverband.configuration.root, '.').gsub(/^\.\//, '')
      end

      def link_to_source_file(source_file)
        %(<a href="##{id source_file}" class="src_link" title="#{shortened_filename source_file}">#{shortened_filename source_file}</a>)
      end
    end
  end
end
