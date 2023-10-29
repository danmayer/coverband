# frozen_string_literal: true

###
# This backports routing redirect active notification events to Rails 6
#
# * reproducing this event: https://github.com/rails/rails/pull/43755/files
#   * and pulls in the later: https://github.com/rails/rails/commit/40dc22f715ede12ab9b7e06d59fae185da2c38c7
# * using alias method although prepend might be an interesting alternative
# * this doesn't backport the built in listener for the event (ActionDispatch::LogSubscriber) as logging isn't needed
###
require "action_dispatch/routing/redirection"

module ActionDispatch
  module Routing
    class Redirect < Endpoint
      def call(env)
        ActiveSupport::Notifications.instrument("redirect.action_dispatch") do |payload|
          request = Request.new(env)
          response = build_response(request)

          payload[:status] = @status
          payload[:location] = response.headers["Location"]
          payload[:request] = request

          response.to_a
        end
      end

      def build_response(req)
        uri = URI.parse(path(req.path_parameters, req))

        unless uri.host
          if relative_path?(uri.path)
            uri.path = "#{req.script_name}/#{uri.path}"
          elsif uri.path.empty?
            uri.path = req.script_name.empty? ? "/" : req.script_name
          end
        end

        uri.scheme ||= req.scheme
        uri.host ||= req.host
        uri.port ||= req.port unless req.standard_port?

        req.commit_flash

        body = ""

        headers = {
          "location" => uri.to_s,
          "content-type" => "text/html",
          "content-length" => body.length.to_s
        }

        ActionDispatch::Response.new(status, headers, body)
      end
    end
  end
end
