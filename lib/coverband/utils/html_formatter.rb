# frozen_string_literal: true

require "erb"
require "cgi"
require "fileutils"
require "digest/sha1"
require "time"

####
# Thanks for all the help SimpleCov https://github.com/colszowka/simplecov-html
# initial version pulled into Coverband from Simplecov 12/04/2018
####
module Coverband
  module Utils
    class HTMLFormatter
      attr_reader :notice, :base_path, :tracker, :page

      def initialize(report, options = {})
        @notice = options.fetch(:notice, nil)
        @base_path = options.fetch(:base_path, "./")
        @tracker = options.fetch(:tracker, nil)
        @page = options.fetch(:page, nil)
        @coverage_result = Coverband::Utils::Results.new(report) if report
      end

      def format_dynamic_html!
        format_html(@coverage_result)
      end

      def format_dynamic_data!
        format_data(@coverage_result)
      end

      def format_settings!
        format_settings
      end

      def format_abstract_tracker!
        template("abstract_tracker").result(binding)
      end

      def format_source_file!(filename)
        source_file = @coverage_result.file_from_path_with_type(filename)

        if source_file
          formatted_source_file(@coverage_result, source_file)
        else
          "File No Longer Available"
        end
      end

      private

      def format_settings
        template("settings").result(binding)
      end

      def format(result)
        Dir[File.join(File.dirname(__FILE__), "../../../public/*")].each do |path|
          FileUtils.cp_r(path, asset_output_path)
        end

        File.open(File.join(output_path, "index.html"), "wb") do |file|
          file.puts template("layout").result(binding)
        end
      end

      def format_html(result)
        template("layout").result(binding)
      end

      def format_data(result)
        template("data").result(binding)
      end

      # Returns the an erb instance for the template of given name
      def template(name)
        ERB.new(File.read(File.join(File.dirname(__FILE__), "../../../views/", "#{name}.erb")))
      end

      def output_path
        "#{File.expand_path(Coverband.configuration.root)}/coverage"
      end

      def asset_output_path
        return @asset_output_path if defined?(@asset_output_path) && @asset_output_path

        @asset_output_path = File.join(output_path)
        FileUtils.mkdir_p(@asset_output_path)
        @asset_output_path
      end

      def served_html?
        true
      end

      def assets_path(name)
        File.join(base_path, name)
      end

      def button(url, title, opts = {})
        delete = opts.fetch(:delete, false)
        button_css = delete ? "coveraband-button del" : "coveraband-button"
        button = "<form action='#{url}' class='coverband-admin-form' method='post'>"
        button += "<button class='#{button_css}' type='submit'>#{title}</button>"
        button + "</form>"
      end

      def display_nav(nav_options = {})
        template("nav").result(binding)
      end

      # Returns the html for the given source_file
      def formatted_source_file(result, source_file)
        template("source_file").result(binding)
      rescue Encoding::CompatibilityError => e
        puts "Encoding error file:#{source_file.filename} Coverband/ERB error #{e.message}."
      end

      # Returns a table containing the given source files
      def formatted_file_list(title, result, source_files, options = {})
        title_id = title.gsub(/^[^a-zA-Z]+/, "").gsub(/[^a-zA-Z0-9\-\_]/, "")
        # Silence a warning by using the following variable to assign to `_`:
        # "warning: possibly useless use of a variable in void context"
        # The variable is used by ERB via binding.
        _ = title_id, options

        template("file_list").result(binding)
      end

      def coverage_css_class(covered_percent)
        if covered_percent.nil?
          ""
        elsif covered_percent > 90
          "green"
        elsif covered_percent > 80
          "yellow"
        else
          "red"
        end
      end

      def strength_css_class(covered_strength)
        if covered_strength > 1
          "green"
        elsif covered_strength == 1
          "yellow"
        else
          "red"
        end
      end

      def missed_lines_css_class(count)
        if count == 0
          "green"
        else
          "red"
        end
      end

      # Return a (kind of) unique id for the source file given. Uses SHA1 on path for the id
      def id(source_file)
        Digest::SHA1.hexdigest(source_file.filename)
      end

      def timeago(time, err_msg = "Not Available")
        if time.respond_to?(:iso8601)
          "<abbr class=\"timeago\" title=\"#{time.iso8601}\">#{time.iso8601}</abbr>"
        else
          err_msg
        end
      end

      def shortened_filename(source_file)
        source_file.short_name
      end

      def link_to_source_file(source_file)
        data_loader_url = "#{base_path}load_file_details?filename=#{source_file.filename}"
        %(<a href="##{id source_file}" class="src_link" title="#{shortened_filename source_file}" data-loader-url="#{data_loader_url}" onclick="src_link_click(this)">#{truncate(shortened_filename(source_file))}</a>)
      end

      def truncate(text, length: 50)
        if text.length <= length
          text
        else
          omission = "..."
          "#{text[0, length - omission.length]}#{omission}"
        end
      end
    end
  end
end
