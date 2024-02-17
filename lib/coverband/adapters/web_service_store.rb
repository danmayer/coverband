# frozen_string_literal: true

module Coverband
  module Adapters
    ###
    # WebServiceStore: store a checkpoint of coverage to a remote service
    ###
    class WebServiceStore < Base
      attr_reader :coverband_url, :process_type, :runtime_env, :hostname, :pid

      def initialize(coverband_url, opts = {})
        super()
        require "socket"
        require "securerandom"
        @coverband_url = coverband_url
        @process_type = opts.fetch(:process_type) { $PROGRAM_NAME&.split("/")&.last || Coverband.configuration.process_type }
        @hostname = opts.fetch(:hostname) { ENV["DYNO"] || Socket.gethostname.force_encoding("utf-8").encode }
        @hostname = @hostname.delete("'", "").delete("’", "")
        @runtime_env = opts.fetch(:runtime_env) { Coverband.configuration.coverband_env }
        @failed_coverage_reports = []
      end

      def logger
        Coverband.configuration.logger
      end

      def clear!
        # done via service UI
        raise "not supported via service"
      end

      def clear_file!(filename)
        # done via service UI
        raise "not supported via service"
      end

      # NOTE: Should support nil to mean not supported
      # the size feature doesn't really makde sense for the service
      def size
        0
      end

      ###
      # Fetch coverband coverage via the API
      # This would allow one to explore from the service and move back to the open source
      # without having to reset coverage
      ###
      def coverage(local_type = nil, opts = {})
        return if Coverband.configuration.service_disabled_dev_test_env?

        local_type ||= opts.key?(:override_type) ? opts[:override_type] : type
        env_filter = opts.key?(:env_filter) ? opts[:env_filter] : "production"
        uri = URI("#{coverband_url}/api/coverage?type=#{local_type}&env_filter=#{env_filter}")
        req = Net::HTTP::Get.new(uri, "content-type" => "application/json", "Coverband-Token" => Coverband.configuration.api_key)
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(req)
        end
        JSON.parse(res.body)
      rescue => e
        logger&.error "Coverband: Error while retrieving coverage #{e}" if Coverband.configuration.verbose || Coverband.configuration.service_dev_mode
      end

      def save_report(report)
        return if report.empty?

        # We set here vs initialize to avoid setting on the primary process vs child processes
        @pid ||= ::Process.pid

        # TODO: do we need dup
        # TODO: we don't need upstream timestamps, server will track first_seen
        Thread.new do
          data = expand_report(report.dup)
          full_package = {
            collection_type: "coverage_delta",
            collection_data: {
              tags: {
                process_type: process_type,
                app_loading: type == Coverband::EAGER_TYPE,
                runtime_env: runtime_env,
                pid: pid,
                hostname: hostname
              },
              file_coverage: data
            }
          }

          save_coverage(full_package)
          retry_failed_reports
        end&.join
      end

      def raw_store
        raise "not supported via service"
      end

      private

      def retry_failed_reports
        retries = []
        @failed_coverage_reports.any? do
          report_body = @failed_coverage_reports.pop
          send_report_body(report_body)
        rescue
          retries << report_body
        end
        retries.each do |report_body|
          add_retry_message(report_body)
        end
      end

      def add_retry_message(report_body)
        if @failed_coverage_reports.length > 5
          logger&.info "Coverband: The errored reporting queue has reached 5. Subsequent reports will not be transmitted"
        else
          @failed_coverage_reports << report_body
        end
      end

      def save_coverage(data)
        if Coverband.configuration.api_key.nil?
          puts "Coverband: Error: no Coverband API key was found!"
          return
        end

        coverage_body = {remote_uuid: SecureRandom.uuid, data: data}.to_json
        send_report_body(coverage_body)
      rescue => e
        add_retry_message(coverage_body)
        logger&.info "Coverband: Error while saving coverage #{e}" if Coverband.configuration.verbose || Coverband.configuration.service_dev_mode
      end

      def send_report_body(coverage_body)
        uri = URI("#{coverband_url}/api/collector")
        req = ::Net::HTTP::Post.new(uri, "content-type" => "application/json", "Coverband-Token" => Coverband.configuration.api_key)
        req.body = coverage_body
        logger&.info "Coverband: saving (#{uri}) #{req.body}" if Coverband.configuration.verbose
        res = ::Net::HTTP.start(
          uri.hostname,
          uri.port,
          open_timeout: Coverband.configuration.coverband_timeout,
          read_timeout: Coverband.configuration.coverband_timeout,
          ssl_timeout: Coverband.configuration.coverband_timeout,
          use_ssl: uri.scheme == "https"
        ) do |http|
          http.request(req)
        end
        if res.code.to_i >= 500
          add_retry_message(coverage_body)
        end
      end
    end
  end
end
