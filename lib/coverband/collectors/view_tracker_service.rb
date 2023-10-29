# frozen_string_literal: true

module Coverband
  module Collectors
    ###
    # This class extends view tracker to support web service reporting
    ###
    class ViewTrackerService < ViewTracker
      def save_report
        reported_time = Time.now.to_i
        if @views_to_record.any?
          relative_views = @views_to_record.map! do |view|
            roots.each do |root|
              view = view.gsub(/#{root}/, "")
            end
            view
          end
          save_tracked_views(views: relative_views, reported_time: reported_time)
        end
        @views_to_record = []
      rescue => e
        # we don't want to raise errors if Coverband can't reach the service
        logger&.error "Coverband: view_tracker failed to store, error #{e.class.name}" if Coverband.configuration.verbose || Coverband.configuration.service_dev_mode
      end

      def self.supported_version?
        defined?(Rails) && defined?(Rails::VERSION) && Rails::VERSION::STRING.split(".").first.to_i >= 4
      end

      private

      def logger
        Coverband.configuration.logger
      end

      def save_tracked_views(views:, reported_time:)
        uri = URI("#{Coverband.configuration.service_url}/api/collector")
        req = Net::HTTP::Post.new(uri, "content-type" => "application/json", "Coverband-Token" => Coverband.configuration.api_key)
        data = {
          collection_type: "view_tracker_delta",
          collection_data: {
            tags: {
              runtime_env: Coverband.configuration.coverband_env
            },
            collection_time: reported_time,
            tracked_views: views
          }
        }
        # puts "sending #{data}"
        req.body = {remote_uuid: SecureRandom.uuid, data: data}.to_json
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
          http.request(req)
        end
      rescue => e
        logger&.error "Coverband: Error while saving coverage #{e}" if Coverband.configuration.verbose || Coverband.configuration.service_dev_mode
      end
    end
  end
end
