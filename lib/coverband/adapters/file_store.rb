# frozen_string_literal: true

module Coverband
  module Adapters
    class FileStore < Base
      attr_accessor :path, :status

      def initialize(path, _opts = {})
        @path = path
        @status  = :free

        config_dir = File.dirname(@path)
        Dir.mkdir config_dir unless File.exist?(config_dir)
      end

      def wait_for_free
        i = 0
        until @status == :free do
          raise "status is: '#{@status}' within '#{i}' attempts " if i > 10
          sleep 1
          i+=1
        end
        true
      end

      def clear!
        File.delete(path) if File.exist?(path)
      end

      def save_report(report)
        results = existing_data(path)
        report.each_pair do |file, values|
          if results.key?(file)
            # convert the keys to "3" opposed to 3
            values = JSON.parse(values.to_json)
            results[file].merge!(values) { |_k, old_v, new_v| old_v.to_i + new_v.to_i }
          else
            results[file] = values
          end
        end
        wait_for_free
        @status  = :recording
        File.open(path, 'w') { |f| f.write(results.to_json) }
        @status  = :free
      end

      def coverage
        existing_data(path)
      end

      def covered_files
        report = existing_data(path)
        existing_data(path).merge(report).keys || []
      end

      def covered_lines_for_file(file)
        report = existing_data(path)
        report[file] || []
      end

      private

      def existing_data(path)
        if File.exist?(path)
          JSON.parse(File.read(path))
        else
          {}
        end
      end
    end
  end
end
